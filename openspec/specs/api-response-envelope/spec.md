## Purpose

定义所有 HTTP 接口的统一响应信封格式与 `code` 分段编码规则，使前端只需实现一次解析逻辑即可处理全部接口的成功与失败结果，不再因接口而异。

## Requirements

### Requirement: 所有 HTTP 响应 SHALL 使用统一信封

服务端返回的每一个响应体 SHALL 是符合信封结构的 JSON 对象，包含 `code`、`msg`、`data` 三个字段。`code` SHALL 为整数，`msg` SHALL 为字符串，`data` SHALL 为对象、数组或 `null`。成功时 `data` SHALL 承载业务数据；失败时 `data` SHALL 为 `null`。

#### Scenario: 成功响应携带数据

- **WHEN** 客户端请求一个能正常返回数据的接口
- **THEN** 响应体为 `{"code":0,"msg":"<中文成功提示>","data":<业务数据>}`

#### Scenario: 失败响应不带数据

- **WHEN** 客户端请求一个不存在的资源
- **THEN** 响应体为 `{"code":<非零错误码>,"msg":"<中文错误提示>","data":null}`

#### Scenario: 响应体字段完整

- **WHEN** 客户端收到任意接口的任意响应
- **THEN** 响应体同时包含 `code`、`msg`、`data` 三个键，不存在缺省或额外字段

### Requirement: HTTP 状态码 SHALL 恒为 200

对于所有已完成路由匹配并产生信封响应的请求，HTTP 状态码 SHALL 恒为 200，真实结果仅由响应体中的 `code` 表达。客户端 SHALL NOT 依赖 HTTP 状态码区分业务成功与业务失败。

#### Scenario: 业务失败仍返回 200

- **WHEN** 客户端请求一个不存在的资源
- **THEN** HTTP 状态码为 200，且响应体中的 `code` 为非零错误码

#### Scenario: 未知路由返回 404 而非信封

- **WHEN** 客户端请求一个未注册的路径
- **THEN** HTTP 状态码为 404，且响应体不是信封结构；该情形 SHALL 由 404 处理器单独处理，不属于信封契约的覆盖范围

### Requirement: `code` SHALL 使用分段编码

`code` SHALL 采用五位分段编码，前 3 位表 HTTP 语义类别，后 2 位表该类别下的业务序号。`0` SHALL 表示成功。已定义的分段为：`400xx` 表示客户端请求错误，`401xx` 表示未认证，`403xx` 表示无权限，`404xx` 表示资源不存在，`500xx` 表示服务端内部错误。

#### Scenario: 成功码为零

- **WHEN** 请求被正常处理完成
- **THEN** 响应体 `code` 为 `0`

#### Scenario: 资源不存在使用 404 分段

- **WHEN** 请求的资源不存在
- **THEN** 响应体 `code` 为 `404xx` 分段中的某一个值，且 `msg` 说明缺失的资源

#### Scenario: 未定义分段不被使用

- **WHEN** 服务端需要返回一个当前尚无对应常量定义的错误
- **THEN** 该错误 SHALL 归入已有分段中最贴近的一类，SHALL NOT 使用未在分段规则中声明的前缀

### Requirement: 信封构造 SHALL 通过集中式辅助函数完成

信封 SHALL 由统一的构造函数生成，而非由各处理函数手写 JSON 字面量。辅助函数 SHALL 至少提供"成功携带数据"与"失败携带错误码与提示"两种构造方式。这使得信封格式的变更只需修改一处。

#### Scenario: 新增接口复用信封构造

- **WHEN** 开发者新增一个接口
- **THEN** 该接口通过统一的辅助函数构造响应，无需自行拼装 `code`/`msg`/`data` 字段

#### Scenario: 信封格式集中变更

- **WHEN** 需要为信封增加一个字段
- **THEN** 只需修改信封结构体与辅助函数，无需逐一改动各处理函数
