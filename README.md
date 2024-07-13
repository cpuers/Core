# Core

## 文档

### 构建文档

```sh
$ pip install mkdocs-material
$ cd docs && mkdocs serve
```

### 编写文档

+ 在 `docs/docs` 中创建 Markdown 文件（以 `.md` 结尾，符合 `.gitignore` 要求）；
+ 在 `docs/mkdocs.yml` 中将文件添加到书籍目录中；

## 运行所有测试

```sh
$ pwd
/path/to/Core
$ make
```
