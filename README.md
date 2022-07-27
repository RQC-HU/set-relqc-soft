# Softwares setup relativistic quantum chemistry

相対論的量子化学計算プログラムのビルドを行うスクリプトです

## Pre-requirements

ビルドにあたっては以下のコマンド、ツールがセットアップされていることを前提とします

- [Intel(R) Fortran compiler](https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)
- [Intel(R) Math kernel library](https://www.intel.com/content/www/us/en/develop/documentation/get-started-with-mkl-for-dpcpp/top.html)

## ビルドされるソフトウェア

- git (version 2.37.1)
- cmake (verson 3.23.2)
- dirac (version 19.0, 21.1, 22.0)
- molcas (version )
- utchem (version )

## How to setup

以下のコマンドを実行するとビルドが実行されます

```sh
 sh setup.sh
```
