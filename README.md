# ExSocks

**Design Chart**

![enter description here](https://github.com/tt67wq/ex_socks/blob/master/socks.png?raw=true)

**Structure**
```
├── apps
│   ├── client  客户端
│   │   ├── lib
│   │   │   ├── client
│   │   │   │   ├── listener.ex 本地监听
│   │   │   │   ├── local_worker.ex  处理本地数据socket
│   │   │   │   └── remote_worker.ex  与远端通信socket
│   │   │   └── client.ex
│   │   ├── mix.exs
│   │   ├── mix.lock
│   │   ├── README.md
│   │   └── test
│   │       ├── client_test.exs
│   │       └── test_helper.exs
│   ├── common
│   │   ├── lib
│   │   │   └── crypto.ex  加解密算法
│   │   ├── mix.exs
│   │   ├── README.md
│   │   └── test
│   │       ├── common_test.exs
│   │       └── test_helper.exs
│   └── server  服务端
│       ├── lib
│       │   ├── server
│       │   │   ├── listener.ex  服务端监听
│       │   │   ├── dns_cache.ex  dns解析缓存
│       │   │   ├── local_worker.ex  与client通信socket
│       │   │   └── remote_worker.ex 处理真正数据请求的socket
│       │   └── server.ex
│       ├── mix.exs
│       ├── mix.lock
│       ├── README.md
│       └── test
│           ├── server_test.exs
│           └── test_helper.exs
├── config
│   └── config.exs
├── mix.exs
├── README.md

```

**Features**
1. 利用poolboy保持一个固定大小的tcp链接池，加速了数据传输的效率；
2. 自定义的加密方法，目前只写了一个aes_256_gcm；
3. 代码结构清晰简单。

**Usage**
***环境要求***
1. erlang/otp > 21.0
2. Elixir > 1.8

 ***服务端***
 1. 配置监听端口和密钥，在server/config/config.exs文件中;
 2. 打包发布，执行mix release;
 3. 执行_build/dev/rel/server/bin/server start/daemon。

***客户端***
1. 配置本地监听端口、远端ip端口和密钥，在client/config/config.exs文件中;
 2. 打包发布，执行mix release;
 3. 执行_build/dev/rel/client/bin/client start/daemon。