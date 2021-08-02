# bilibili_console

#### 介绍

B站命令行客户端Ruby版

#### 软件结构

基于ruby开发，ruby version >= 2.7

#### 安装教程

1. 安装ruby环境，使用[rvm](https://ruby-china.org/wiki/rvm-guide)或[rbenv](https://ruby-china.org/wiki/rbenv-guide)均可
2. 替换gem源
3. 进入代码根目录，执行一下操作：
```shell
$ gem build bilibili_console.gemspec
$ gem install bilibili_console-0.0.1.gem
```

### 使用方法

gem安装完成后即可使用**bili-console**命令

#### 帮助信息

```shell
$ bili-console help
```

#### 登录

```shell
# 执行二维码登录
$ bili-console login
```

#### 用户基本信息

```shell
$ bili-console user
```

#### bilibili漫画签到

```shell
# 目前只提供漫画签到的功能
$ bili-console manga
```

#### 功能清单

* [x] bilibili漫画签到 
* [x] B站二维码登录 
* [x] 查看个人信息
* [ ] 根据bv下载视频并自动合并 
* [ ] 查看个人收藏夹
* [ ] 视频检索


#### 参与贡献

Fork本仓库，提交PR即可
