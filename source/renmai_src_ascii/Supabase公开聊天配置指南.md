# 仁迈公开聊天配置指南

> 归档说明
>
> 本文档对应的是仁迈早期“公开聊天 / 网页版 / Supabase 在线服务”方案。
> 当前主产品已经转为 `Windows 桌面端聊天记录分析助手`，不再以公开聊天、注册登录或实时消息为主链路。
> 如无明确旧版维护需求，请优先参考当前桌面版 README、使用说明书和软件设计说明书，不要再把本文作为现行实施方案。

这份指南对应当前网页端版本，目标是让你把“本地演示聊天”切换成“公开访问 + 真实多人聊天”。

完成后，你可以做到：

- 通过网页公开访问 `仁迈`
- 使用真实邮箱注册和登录
- 搜索其他公开用户
- 和其他用户发起一对一聊天
- 让消息只对会话成员可见

---

## 一、你现在已经有的内容

项目里已经准备好了这些文件：

- `index.html`
- `public-chat.js`
- `functions/api/public-config.js`
- `supabase/schema.sql`
- `.dev.vars.example`
- `.env.example`

这意味着前端页面、Cloudflare 同域公开配置接口、Supabase 数据表和权限规则都已经写好了。  
你现在缺的是“把它们接到你自己的 Supabase 项目”。

---

## 二、先创建 Supabase 项目

官方入口：

- https://supabase.com/dashboard

操作步骤：

1. 登录 Supabase Dashboard。
2. 点击 `New project`。
3. 选择组织。
4. 填写项目名，例如：`renmai-chat`。
5. 选择数据库密码并保存。
6. 选择地区，尽量选离目标用户近的区域。
7. 等待项目初始化完成。

参考资料：

- Supabase 教程类文档里当前仍然是“先 Create a new project in the Supabase Dashboard，再配置数据库与 API”  
  https://supabase.com/docs/guides/getting-started/tutorials/with-react

---

## 三、导入当前项目的聊天表结构

你已经有现成 SQL：

- [schema.sql](c:/Users/Administrator/Desktop/新建文件夹/新建文件夹/renmai/supabase/schema.sql)

操作步骤：

1. 进入 Supabase 项目。
2. 打开 `SQL Editor`。
3. 新建一个查询。
4. 把 `supabase/schema.sql` 的全部内容粘进去。
5. 点击 `Run`。

这一步会创建：

- `profiles`
- `conversations`
- `conversation_members`
- `messages`

同时也会创建：

- RLS 权限策略
- `start_direct_conversation(uuid)` 函数
- `list_my_direct_conversations()` 函数

这两组 RPC 就是网页端真实聊天现在直接调用的接口。

参考资料：

- Supabase 教程文档说明可以直接在 SQL Editor 里粘贴并运行 SQL  
  https://supabase.com/docs/guides/getting-started/tutorials/with-react
- Supabase RLS 文档  
  https://supabase.com/docs/guides/database/postgres/row-level-security

---

## 四、开启邮箱注册登录

当前网页端公开聊天用的是邮箱 + 密码登录。

操作步骤：

1. 在 Supabase 项目里打开 `Authentication`。
2. 找到 `Providers`。
3. 确认 `Email` 已开启。

注意：

- Supabase 官方文档说明，`Email authentication is enabled by default`。
- 托管项目默认通常要求邮箱确认后再登录。

如果你只是今天先测试，可以用两个真实邮箱各收一次验证邮件。

参考资料：

- Supabase Password-based Auth  
  https://supabase.com/docs/guides/auth/passwords

---

## 五、配置站点地址和回跳地址

这一步很重要，不然注册后邮箱确认链接跳不回来。

操作步骤：

1. 在 Supabase 项目中打开 `Authentication`。
2. 打开 `URL Configuration`。
3. 设置 `Site URL`。
4. 把你的网页地址加入 `Redirect URLs`。

本地开发时建议至少加：

- `http://localhost:8788`
- `http://127.0.0.1:8788`

如果你后面部署到 Cloudflare Pages，再补：

- `https://你的项目.pages.dev`
- `https://你的正式域名`

参考资料：

- Supabase Redirect URLs  
  https://supabase.com/docs/guides/auth/redirect-urls

---

## 六、拿到公开可用的 Supabase 配置

你需要 2 个值：

- `PUBLIC_SUPABASE_URL`
- `PUBLIC_SUPABASE_ANON_KEY` 或 `PUBLIC_SUPABASE_PUBLISHABLE_KEY`

获取方式：

1. 打开 Supabase 项目。
2. 进入 `Settings`。
3. 找到 API / API Keys 页面。
4. 复制项目 URL。
5. 复制客户端可公开使用的 `anon` key 或 `publishable key`。

注意：

- 前端只能放公开 key。
- 不要把 `service_role` 放到浏览器或仓库里。

---

## 七、本地接入项目

在项目根目录创建：

- `.dev.vars`

内容格式：

```env
GEOAPIFY_API_KEY=你的GeoapifyKey
PUBLIC_SUPABASE_URL=https://你的项目.supabase.co
PUBLIC_SUPABASE_ANON_KEY=你的Supabase公开Key
PUBLIC_SUPABASE_PUBLISHABLE_KEY=你的Supabase公开PublishableKey
RENMAI_TEXT_MODEL=@cf/meta/llama-3.1-8b-instruct-fast
RENMAI_VISION_MODEL=@cf/meta/llama-3.2-11b-vision-instruct
RENMAI_GEO_LANG=zh-CN
RENMAI_AUTO_ACCEPT_META_LICENSE=false
```

可以直接参考：

- [.dev.vars.example](c:/Users/Administrator/Desktop/新建文件夹/新建文件夹/renmai/.dev.vars.example)

---

## 八、本地启动网页

你现在这套网页建议用 Cloudflare Pages 本地开发方式启动。

命令：

```powershell
wrangler pages dev .
```

如果本机还没装 Wrangler：

```powershell
npm install -g wrangler
```

启动后一般会给你一个本地地址，例如：

- `http://localhost:8788`

然后你就能用这个地址访问网页。

参考资料：

- Cloudflare Pages Functions / Bindings  
  https://developers.cloudflare.com/pages/functions/bindings/

---

## 九、第一次验证真实聊天

建议你这样测：

1. 打开浏览器窗口 A。
2. 打开浏览器无痕窗口或另一个浏览器窗口 B。
3. 两边都打开同一个本地地址或部署地址。
4. 用两个不同邮箱分别注册两个账号。
5. 回邮箱确认注册链接。
6. 两边重新登录。
7. 在消息页顶部的 `真实对话` 区域搜索对方昵称或 handle。
8. 点 `发起对话`。
9. 双方互发消息。

如果成功，你会看到：

- 左侧出现真实会话列表
- 中间出现实时消息流
- 刷新页面后会话仍然存在

---

## 十、部署到 Cloudflare Pages

你后面要公开给别人访问时，再做这一步。

操作步骤：

1. 把项目推到 GitHub。
2. 登录 Cloudflare Dashboard。
3. 打开 `Workers & Pages`。
4. 选择 `Create application`。
5. 连接 Git 仓库。
6. 构建输出按当前静态项目配置。
7. 在 Pages 项目里打开 `Settings`。
8. 到 `Variables and Secrets` 添加：
   - `GEOAPIFY_API_KEY`
   - `PUBLIC_SUPABASE_URL`
   - `PUBLIC_SUPABASE_ANON_KEY`
   - 其他当前 `.dev.vars` 里的变量
9. 重新部署。

参考资料：

- Cloudflare Pages 环境变量 / Bindings  
  https://developers.cloudflare.com/pages/functions/bindings/
- Cloudflare Pages Build Configuration  
  https://developers.cloudflare.com/pages/configuration/build-configuration/

---

## 十一、现在最常见的 5 个问题

### 1. 注册后没法自动回来

通常是 `Site URL` 或 `Redirect URLs` 没配好。

### 2. 邮件收不到

Supabase 官方说明默认邮件服务有速率限制，适合测试，不适合正式生产。

参考：

- https://supabase.com/docs/guides/auth/passwords

### 3. 登录成功但消息页还是本地模式

通常是：

- `.dev.vars` 没填
- Pages 环境变量没填
- `/api/public-config` 没返回真实值

### 4. 能登录但搜不到其他人

通常是另一位用户还没完成注册确认，或 `profiles` 还没正确写入。

### 5. 能搜到人但发不出消息

通常是：

- `schema.sql` 没完整执行
- RLS 或 RPC 没创建成功

---

## 十二、你现在最短路径怎么做

如果你的目标是“今天就试着和别人聊一下”，最短路径是：

1. 创建 Supabase 项目
2. 执行 `supabase/schema.sql`
3. 配好 `Email` 和 `URL Configuration`
4. 填 `.dev.vars`
5. 运行 `wrangler pages dev .`
6. 用两个邮箱在两个窗口注册
7. 互相搜索并发消息

---

## 十三、当前项目里和这件事直接相关的文件

- [index.html](c:/Users/Administrator/Desktop/新建文件夹/新建文件夹/renmai/index.html)
- [public-chat.js](c:/Users/Administrator/Desktop/新建文件夹/新建文件夹/renmai/public-chat.js)
- [functions/api/public-config.js](c:/Users/Administrator/Desktop/新建文件夹/新建文件夹/renmai/functions/api/public-config.js)
- [supabase/schema.sql](c:/Users/Administrator/Desktop/新建文件夹/新建文件夹/renmai/supabase/schema.sql)
- [.dev.vars.example](c:/Users/Administrator/Desktop/新建文件夹/新建文件夹/renmai/.dev.vars.example)

---

## 十四、下一步怎么继续

当你做到下面任意一步时，可以直接继续让我接着带：

- 你已经创建好了 Supabase 项目
- 你已经拿到了 URL 和 anon key
- 你已经把 `.dev.vars` 填好了
- 你已经运行 SQL，但报错了

到时候你只要对我说一句：

`继续带我配置 Supabase`

或者直接把报错贴给我，我会按你的当前进度接着往下带。
