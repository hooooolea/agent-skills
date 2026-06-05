---
name: spring-boot-mybatisplus-unit-test
description: Spring Boot + MyBatis-Plus service layer unit testing with Mockito — covers LambdaQueryWrapper setup, Redis template mocking, WebMvcTest slice testing, and SecurityContext principal compatibility.
category: software-development
tags: [spring-boot, mybatis-plus, mockito, unit-test, redis, spring-security]
created: 2026-05-15
updated: 2026-05-15
---

# Spring Boot MyBatis-Plus Service Unit Test

## When to Use

- Writing unit tests for `@Service` classes that use MyBatis-Plus `LambdaQueryWrapper` queries
- Tests fail with "can not find lambda cache for this entity" when mocking mapper `selectCount`/`selectOne`
- Adding `@WebMvcTest` slice tests after a controller gains new `@Autowired` dependencies (e.g., mapper injection)
- `SecurityContextHolder` principal type differs between real JWT flow (`String`) and test context (`UserDetails`)

---

## 1. MyBatis-Plus LambdaQueryWrapper in Unit Tests

MyBatis-Plus requires `TableInfoHelper.initTableInfo()` to build Lambda query chains in mocked contexts.

```java
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import org.apache.ibatis.builder.MapperBuilderAssistant;

@ExtendWith(MockitoExtension.class)
class XxxServiceTest {

    private XxxServiceImpl xxxService;

    @Mock
    private XxxMapper xxxMapper;

    @BeforeEach
    void setUp() {
        xxxService = new XxxServiceImpl(xxxMapper /*, other deps */);

        // REQUIRED: initialize TableInfoHelper for each entity used in LambdaQueryWrapper
        MybatisConfiguration config = new MybatisConfiguration();
        MapperBuilderAssistant assistant = new MapperBuilderAssistant(config, "test-namespace");
        TableInfoHelper.initTableInfo(assistant, EntityClass1.class);
        TableInfoHelper.initTableInfo(assistant, EntityClass2.class);
    }
}
```

**Without this**, any `xxxMapper.selectCount(any(LambdaQueryWrapper.class))` throws:
```
MybatisPlus can not find lambda cache for this entity [com.xxx.Entity]
```

---

## 2. Mocking Mapper Methods with Sequential Returns

When a service calls the same mapper method multiple times with different query types (e.g., `approved` then `pending` counts), use Mockito's sequential stubbing:

```java
// WRONG: all calls return the same value
when(merchantMapper.selectCount(any(LambdaQueryWrapper.class))).thenReturn(20L);

// CORRECT: first call returns approved count, second returns pending count
when(merchantMapper.selectCount(any(LambdaQueryWrapper.class)))
        .thenReturn(20L)   // approved
        .thenReturn(5L);   // pending
```

MyBatis-Plus uses `?` placeholders — SQL strings in `getSqlSegment()` don't contain literal values, so string-matching the query content to differentiate calls is unreliable.

---

## 3. @WebMvcTest Slice Tests — New Controller Dependencies

When a controller gains new `@Autowired` fields (e.g., mapper injection), `@WebMvcTest` slices fail with `NoSuchBeanException` unless those dependencies are mocked.

**Symptom**: Tests that passed before controller modification now fail with:
```
org.springframework.beans.factory.NoSuchBeanException: No qualifying bean of type 'com.xxx.Mapper'
```

**Fix**: Add `@MockitoBean` for every new mapper/service the controller now depends on:

```java
@WebMvcTest({ XxxController.class, YyyController.class })
@ContextConfiguration(classes = { XxxController.class, YyyController.class, SecurityConfig.class, ... })
class XxxControllerTest {

    @MockitoBean
    private XxxService xxxService;

    // Add these after controller gains new mapper/service dependencies
    @MockitoBean
    private XxxMapper xxxMapper;

    @MockitoBean
    private YyyMapper yyyMapper;
}
```

---

## 4. SecurityContext Principal Type Compatibility

Real JWT flow: `JwtAuthenticationFilter` sets principal as `String` (username).

Test `@WithMockUser`: principal is `UserDetails` (Spring Security's implementation).

**Symptom**: Controller's `getCurrentUserId()` checks `instanceof String` — works in real requests but fails in tests because principal is `UserDetails`.

```java
// BROKEN: only handles String principal
if (authentication.getPrincipal() instanceof String username) {
    // works in real flow
}

// FIXED: handle both
Object principal = authentication.getPrincipal();
if (principal instanceof String) {
    username = (String) principal;
} else if (principal instanceof UserDetails) {
    username = ((UserDetails) principal).getUsername();
} else {
    throw new BusinessException(401, "登录状态无效");
}
```

Also add `import org.springframework.security.core.userdetails.UserDetails;`

---

## 5. Common Test Fixes for Field Name Changes

When a VO field is renamed (e.g., `salesAmount` → `totalSalesAmount`), existing `@WebMvcTest` assertions and service mock returns need updates:

**Mock return**: change setter name
```java
// Before
statsVO.setSalesAmount(BigDecimal.ZERO);
// After
statsVO.setTotalSalesAmount(BigDecimal.ZERO);
```

**JSON path assertion**: change JSON path
```java
// Before
.andExpect(jsonPath("$.data.salesAmount").value(88.8))
// After
.andExpect(jsonPath("$.data.totalSalesAmount").value(88.8))
```

---

## 6. Running Tests

```bash
# Single test class
./mvnw test -Dtest=AdminStatsServiceTest

# All tests
./mvnw test

# Specific method
./mvnw test -Dtest=AdminStatsServiceTest#getAdminStatsShouldQueryAllTablesAndCacheWhenCacheMiss
```

---

## Pitfalls

1. **LambdaQueryWrapper without TableInfoHelper** — always initialize in `@BeforeEach`
2. **Sequential mapper calls** — use `.thenReturn(a).thenReturn(b)` not answer/match by SQL content
3. **New controller dependencies in @WebMvcTest** — always add `@MockitoBean` for each new injected dependency
4. **Principal type mismatch** — handle both `String` and `UserDetails` in SecurityContext reads
5. **VO field rename side effects** — check existing tests for setter names and JSON paths when renaming fields
