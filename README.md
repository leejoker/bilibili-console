# bilibili_console

[![Gem Version](https://img.shields.io/gem/v/bilibili_console.svg)][ruby-gems]

[ruby-gems]: https://rubygems.org/gems/bilibili_console

#### 1 介绍

B站命令行客户端

#### 2 软件结构

基于ruby开发，ruby version >= 2.7

#### 3 安装教程

1. 安装ruby环境，使用[rvm](https://ruby-china.org/wiki/rvm-guide)或[rbenv](https://ruby-china.org/wiki/rbenv-guide)均可
2. 替换gem源
3. 进入代码根目录，执行一下操作：

```shell
$ gem build bilibili_console.gemspec
$ gem install bilibili_console-0.0.3.gem
```

### 4 使用方法

gem安装完成后即可使用**bilic**命令

#### 4.1 帮助信息

```shell
$ bilic help
```

#### 4.2 登录

```shell
# 执行二维码登录
$ bilic login
```

#### 4.3 用户基本信息

```shell
$ bilic user
```

#### 4.4 下载指定BV视频

```shell
# 下载全部分P
$ bilic down bv_id

# 从指定分P开始下载
$ bilic down -s 1 bv_id

# 从指定分P结束
$ bilic down -e 10 bv_id

# 下载指定分P
$ bilic down -p 2 bv_id
```

#### 4.5 查询收藏

```shell
# 查询所有收藏
$ bilic fav

# 从收藏检索
$ bilic fav --search 检索关键词

# 检索指定收藏夹
$ bilic fav --page_size 20 --page_num 1 --fav 收藏夹id --all {0 从当前收藏夹检索, 1 从全局检索}
```

#### 4.6 bilibili漫画签到

```shell
# 目前只提供漫画签到的功能
$ bilic manga
```

#### 4.7 视频搜索

```shell
$ bilic search --page 2 av170001
```

#### 5 功能清单

##### DONE

- bilibili漫画签到
- B站二维码登录
- 查看个人信息
- 根据bv下载视频
- 合并下载的视频
- 查看个人收藏夹
- 搜索个人收藏夹
- 指定分p下载
- 从指定分p开始下载
- 下载到指定分P结束
- 全局视频检索(目前只支持搜索视频)

##### TODO

- 多类型全局检索
- 增加下载视频自动上传阿里云盘

#### 6 相关项目

##### Gem依赖

* [nice_http](https://github.com/MarioRuiz/nice_http)
* [rqrcode](https://github.com/whomwah/rqrcode/)
* [thor](https://github.com/rails/thor)

##### 接口文档

* [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect) 感谢易姐的文档支持！
* [Bilibili-Manga](https://github.com/xkk2333/Bilibili-Manga) 参考了B站漫画的签到接口
