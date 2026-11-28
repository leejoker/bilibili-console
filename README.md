# bilibili_console

[![Gem Version](https://img.shields.io/gem/v/bilibili_console.svg)][ruby-gems]

[ruby-gems]: https://rubygems.org/gems/bilibili_console

#### 1 介绍

B站命令行客户端

#### 2 软件结构

基于ruby开发，ruby version >= 3.2

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

# 重命名下载文件
$ bilic down bv_id --rename "demo"

# 并行下载（任务化，默认 1 个 worker）
$ bilic down bv_id --workers 2
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
# 查看指定分页
$ bilic search --page 2 av170001
# 指定BV查看
$ bilic search --bv BV1zL411L75A
# 保存指定BV封面
$ bilic search BV1zL411L75A --bv --pic
```

#### 4.8 管理已下载项

```shell
# 列出已下载的视频（按体积排序）
$ bilic down --list

# 预览将删除的下载目录
$ bilic down BV1zL411L75A --remove

# 确认删除
$ bilic down BV1zL411L75A --remove --yes
```

#### 4.9 查看观看历史

```shell
# 最近 20 条
$ bilic history

# 指定分页与每页数量
$ bilic history --page 2 --count 10
```

#### 4.10 本地播放器播放

```shell
# 解析播放地址并交给本地播放器（mpv -> vlc -> xdg-open）
$ bilic play BV1zL411L75A

# 指定分P与清晰度
$ bilic play BV1zL411L75A --page 2 --qn 480

# 只打印播放地址，不启动播放器
$ bilic play BV1zL411L75A --no_launch
```

#### 4.11 saucenao 图片检索

```shell
# 以图搜图（支持图片地址或本地文件），需要 saucenao api key
$ bilic saucenao https://i0.hdslb.com/bfs/archive/xxx.jpg
$ bilic saucenao ./cover.jpg --db 999
```

#### 4.13 下载任务

下载按任务执行：每个分片是一条任务记录，状态持久化在 `~/.bc/tasks.json`，中断后可继续。

```shell
# 列出任务（状态、进度、失败分片数）
$ bilic tasks

# 查看任务详情（含每个分片的状态与大小）
$ bilic tasks <task-id>

# 重试失败分片（继续未完成的下载）
$ bilic tasks <task-id> --retry

# 请求取消正在运行的任务（当前分片完成后停止）
$ bilic tasks <task-id> --cancel

# 删除任务记录（下载文件保留）
$ bilic tasks <task-id> --remove
```

- 同一 bv 若存在未完成任务，`bilic down` 会直接续传，不会重复下载已完成分片
- 分P 有多分片时需要 `ffmpeg` 合并；未安装时会明确报错并保留分片文件，安装后 `bilic tasks <id> --retry` 即可合并
- 任务并发数：`--workers N`（1–8，默认 1）

#### 4.12 配置文件

配置位于 `~/.bc/bilic.conf`（JSON），除代理外新增两个可选键：

```json
{
  "proxy": "127.0.0.1:7890",
  "proxy_type": "http",
  "player": "mpv",
  "saucenao_api_key": "your key"
}
```

- `proxy`：bilibili 直连受限时需要代理，否则请求会被重置
- `player`：本地播放器命令，留空则自动探测 mpv / vlc / xdg-open
- `saucenao_api_key`：saucenao 图片检索的 API key，也可用环境变量 `SAUCENAO_API_KEY`（匿名账号不允许调用 JSON API）

#### 5 功能清单

##### RELEASE NOTES

###### 0.0.3

- bilibili漫画签到
- B站二维码登录
- 查看个人信息
- 根据bv下载视频（指定分p，分p范围选择，分片合并）
- 个人收藏夹（查看、搜索）
- 全局视频检索(目前只支持搜索视频)
- 视频封面提取

###### 0.0.4

- 增加doctor诊断
- 支持aria2c下载
- 支持下载视频重命名
- 获取视频评论区内容
- 支持下载评论区图片
- 管理已下载项（list / remove）
- 查看观看历史
- 调用本地播放器播放
- saucenao 图片检索
- 下载任务化（断点续传、重试、取消、并发 workers）

#### 6 相关项目

##### Gem依赖

* [nokogiri](https://github.com/sparklemotion/nokogiri)
* [rqrcode](https://github.com/whomwah/rqrcode/)
* [rubyzip](https://github.com/rubyzip/rubyzip)
* [socksify](https://github.com/astro/socksify-ruby)
* [thor](https://github.com/rails/thor)

##### 接口文档

* [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect) 感谢易姐的文档支持！
* [Bilibili-Manga](https://github.com/xkk2333/Bilibili-Manga) 参考了B站漫画的签到接口