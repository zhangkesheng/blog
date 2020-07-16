---
title: Go 项目结构规范
date: 2020-04-02 15:02:56
tags: 
    - Go
    - Level0
categories: 翻译
---

# Go 项目结构规范

> 原文地址: [Standard Go Project Layout](https://github.com/golang-standards/project-layout)

这是Go项目的一个基础规范. 这不是Go开发团队定义的官方规范; 然而, 这是Go生态中历史和新建项目的一个常用配置.其中的一些模式比其他模式更受欢迎. 它有一些小的增强功能以及支持目录, 这些对于任何足够大的实际项目都是通用的.

如果你正在尝试学习Go语言, 或者在构建验证性测试, 或者只是一个小玩意, 使用这个项目布局就有些太夸张了. 从简单的事情开始(一个简单的`main.go`就足够了). 请记住, 随着项目的发展, 确保你的代码结构合理是非常重要的, 否则你最后将收获一个隐藏很多依赖和全局状态的杂乱代码. 当你的项目拥有很多参与者的时候你就需要更多的结构. 这时候, 采用一个通用的包/库的管理方法就很重要. 当你有一个开源项目或者你知道有人引用了你项目仓库中的代码时, 你就必须有一个私有的(又名`内部的`)包和代码. 克隆这个项目, 保留你需要的然后删除其他所有的东西!  只是因为你并不需要使用到这个项目中的所有东西. 这些模式并不是在每个项目中出现. 即使`vendor`模式也不是普遍使用的.

注意`Go modules`和它的相关功能将会影响你的项目结构. 一旦默认开启全部功能, 代码仓库将会更新为包含`Go modules`. 同时, 请随时在[issues](https://github.com/golang-standards/project-layout/issues/18)中提出你的想法和意见.

这个项目的结构是有意设为通用的, 并没有去引入特定的Go包结构.

这是个社区共同完善的项目. 如果你发现一个新的模式, 或者觉得项目中的某个模式需要更新, 请提交Issue.

如果你在开始使用`gofmt`和`golint`时遇到命名, 格式化和样式问题. 请确保阅读这些Go样式指南和建议:

- https://talks.golang.org/2014/names.slide
- https://golang.org/doc/effective_go.html#names
- https://blog.golang.org/package-names
- https://github.com/golang/go/wiki/CodeReviewComments
- [Style guideline for Go packages](https://rakyll.org/style-packages) (rakyll/JBD)

查看[`Go项目结构`](https://medium.com/golang-learn/go-project-layout-e5213cdcfaa2) 获取更多背景信息.

更多关于命名和包管理以及其他代码结构的建议:

- [GopherCon EU 2018: Peter Bourgon - Best Practices for Industrial Programming](https://www.youtube.com/watch?v=PTE4VJIdHPg)
- [GopherCon Russia 2018: Ashley McNamara + Brian Ketelsen - Go best practices.](https://www.youtube.com/watch?v=MzTcsI6tn-0)
- [GopherCon 2017: Edward Muller - Go Anti-Patterns](https://www.youtube.com/watch?v=ltqV6pDKZD8)
- [GopherCon 2018: Kat Zien - How Do You Structure Your Go Apps](https://www.youtube.com/watch?v=oL6JBUk6tj0)

## Go目录结构

### `/cmd`

项目的主要应用.

目录名称需要和每个应用的可执行文件名称一致.(e.g.,`/cmd/app`)

应用目录不要放太多代码. 如果你认为某段代码可以被导入到其他项目使用, 那么它应该放在`/pkg`目录下. 如果代码是不可重用的或者你不希望其他人重用它, 那么就应该放在`/internal`目录. 你会惊讶于别人会做什么, 所以要明确你的意图!

通常会有一个简小的`main`方法来引入和调用`internal`和`pkg`目录下的代码, 除此之外没有其他的东西.

查看[`cmd`](https://github.com/golang-standards/project-layout/blob/master/cmd/README.md)的示例

### `/internal`

私有的应用和代码库. 这里是一些你不想别人在应用或代码库中引用的代码. 请注意, Go编译器自身是强制执行这个布局模式的. 想知道更多细节可以查看Go 1.4的[发行说明](https://golang.org/doc/go1.4#internalpackages). 注意`internal`并不限于顶层目录. 你可以在任意的目录层级下创建不止一个`internal`目录.

你可以在在内部目录里添加一些额外的结构体来隔离你的共享和非共享的内部代码. 有一个一眼就可以看出用途的报名是很好的, 但这并不是必须的(特别是对于一些很小的项目来说). 实际的应用代码可以放在`/internal/app`目录下(e.g., `/internal/app/myapp`), 这些应用的共享代码放在`internal/pkg`目录下(e.g., `/internal/pkg/myprivlib`).

`/pkg`

这个库的代码可以被外部应用使用(e.g., `/pkg/mypubliclib`). 其他库会引入这些库, 并期望他们可以使用, 所以在这里放入代码前请三思:-) 请注意`internal`目录是确保你的代码时不可引入的更好的方法, 因为这是被Go强制执行的. `pkg`目录仍是一个明确的告知别人该目录下的代码可以安全使用的好办法. Travis Jeffery发布的博客[`我将用pkg代替internal`](https://travisjeffery.com/b/2019/11/i-ll-take-pkg-over-internal/)提供了一个对`pkg`和`internal`目录很好的概述, 及其何时使用它们更有意义.

当你的根目录包含许多非Go组件和文件夹时, 这也是一个将代码分组的好方法, 可以使你更轻松的使用Go的工具(正如下面这些文章中提到的: [`工业化编程的最佳实践`](https://www.youtube.com/watch?v=PTE4VJIdHPg)- GopherCon 欧盟 2018, [GopherCon 2018: Kat Zien - 你该如何结构化你的Go应用](https://www.youtube.com/watch?v=oL6JBUk6tj0)和[Golab 2018 - Massimiliano Pippi - Go项目布局模式]).

如果你想看有哪些流行的Go项目是用这种布局模式, 可以查看[`/pkg`](https://github.com/golang-standards/project-layout/blob/master/pkg/README.md)目录. 这是一种常见的布局模式, 但它并没有被普遍接受, 并且一些Go社区的人不推荐它.

如果你的项目真的很小或者一层额外的嵌套不会增加太多价值, 不使用这个模式也是可以的(除非你真的想用:-)). 当你的项目足够大并且根目录包含太多东西时, 可以考虑使用这个模式(特别是如果你有很多非Go组件的时候).

### `/vender`

应用依赖(手动管理或者使用你喜欢用的工具, 比如新的内置特性[`Go Modules`](https://github.com/golang/go/wiki/Modules)). `go mod vender`命令会为你新建`/vender`目录. 请注意, 如果你没有使用默认启用的Go 1.14版本, 你可能需要在`go build`命令中添加`-mod=vender`标志.

如果你在构建库, 请不要提交应用的依赖项

注意, 直到[`1.13`](https://golang.org/doc/go1.13#modules)版本Go还启用组件代理的特性(默认使用`[https://proxy.golang.org/]`(https://proxy.golang.org/)作为组件代理服务器). 在[`此处`](https://blog.golang.org/module-mirror-launch)阅读更多信息, 了解他是否适合你所有的依赖和约束. 如果是的, 那你就完全不需要`vender`目录.

## 服务端应用目录

### `/api`

OpenApi/Swagger 规范, JSON模式文件, 协议定义文件.

相关示例, 请查看[`/api`](https://github.com/golang-standards/project-layout/blob/master/api/README.md)目录

## Web端应用目录

### `/web`

Web应用具体的组件, 静态文件, 服务端模板和单页应用.

## 通用的应用目录

### `/configs`

配置文件模拟或者默认配置.

把`confd`或者`consul-template`模板文件放在这.

### `/init`

系统初始化(systemd, upstart, sysv)以及进程管理(runit, supervisord)配置

### `/scripts`

各种执行构建, 安装, 分析等操作的脚步

这些脚步会让根目录下的Makefile变得小而简单(e.g., [https://github.com/hashicorp/terraform/blob/master/Makefile](https://github.com/hashicorp/terraform/blob/master/Makefile))

相关示例, 请查看[`/scripts`](https://github.com/golang-standards/project-layout/blob/master/scripts/README.md)目录

### `/build`

打包和持续集成.

将云(AMI), 容器(Docker), 操作系统(deb, rpm, pkg)的包配置和脚本放在`build/package`目录下.

将持续集成(travis, circle, drone)的配置和脚本放在`/build/ci`目录下. 请注意, 一些CI工具(e.g., Travis)对于配置文件的位置是非常敏感的. 将配置放在`/build/ci`目录下, 并链接到CI工具期望她们所处的位置(如果可能的话).

### `/deployments`

IaaS, PaaS, 系统和容器编排部署的配置和模板(docker-compose, kubernetes/helm, mesos, terraform, bosh). 注意, 在一些代码库中(特别是使用kubernetes部署的应用), 这个目录叫`/deploy`

### `/test`

额外的外部测试应用和测试数据. 你可以随时根据需要构建`/test`目录. 对于大型项目来说. 有数据的子目录是有意义的. 例如, 如果你想Go忽略这个目录下的数据, 你可以使用`/test/data`或`/test/testdata`

相关示例, 请查看[`/test`](https://github.com/golang-standards/project-layout/blob/master/test/README.md)目录

## 其他目录

### `/docs`

设计和用户文档(除了godoc生成的文档)

相关示例, 请查看[`/docs`](https://github.com/golang-standards/project-layout/blob/master/docs/README.md)目录

### `/tools`

项目的配套工具集. 注意, 这里的代码可以被`pkg`和`internal`目录引用.

相关示例, 请查看[`/tools`](https://github.com/golang-standards/project-layout/blob/master/tools/README.md)目录

### `/examples`

应用或者公共库的示例

相关示例, 请查看[`/examples`](https://github.com/golang-standards/project-layout/blob/master/examples/README.md)目录

### `/third_party`

外部的帮助工具, fork的代码以及第三方的工具类.(e.g., Swagger UI)

### `/githooks`

Git hooks.

### `/asserts`

与代码库相关的其他静态文件(图片, Logo等)

### `/website`

如果你没有使用Github Pages, 这里放项目的网站数据.

相关示例, 请查看[`/website`](https://github.com/golang-standards/project-layout/blob/master/website/README.md)目录

## 不该拥有的目录

### `/src`

有些Go项目确实包含`src`文件夹, 但这通常发生在那些从Java世界过来的开发者身上, 在那里这是一种常见的模式. 如果可以, 尝试不要采用这种Java的模式. 你应该也不想你的Go代码和项目看起来像Java:-)

不要混淆项目级别的`/src`目录和Go在[`如何编写Go代码`](https://golang.org/doc/code.html)中描述的用作工作空间的`/src`目录. `$GOPATH`环境变量指向你(当前用户)的工作空间(非Windows系统中, 默认指向`$HOME/go`). 这个工作空间包含顶级的`/pkg`, `/bin`以及`/src`目录. 你的实际项目最终被放在`/src`下二级子目录下, 所以如果你的项目有`/src`目录, 项目路径就将是这样: `/some/path/to/workspace/src/your_project/src/your_code.go`. 请注意, Go 1.11允许你的项目在`GOPATH`目录外, 但这也并不意味着使用这个模式是一个好主意.

TO BE CONTINUE