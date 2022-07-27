# Softwares setup relativistic quantum chemistry

相対論的量子化学計算プログラムのビルドを行うスクリプトです

## Pre-requirements

ビルドにあたっては以下のコマンド、ツールがセットアップされていることを前提とします

- MOLCAS
  - license.dat(ライセンスファイル)が./molcasディレクトリもしくは$HOME/.Molcasディレクトリ直下に配置されていること
- Intel(R) Fortran compiler, Math kernel library
  - [Intel(R) Fortran compiler](https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)
  - [Intel(R) Math kernel library](https://www.intel.com/content/www/us/en/develop/documentation/get-started-with-mkl-for-dpcpp/top.html)
  - 上記2つはsudo権限及びインターネットへの接続が可能なら以下のコマンドでインストールできます

  ```sh
  sudo sh intel-fortran.sh
  ```

## ビルドされるソフトウェア

- git (version 2.37.1)
- cmake (verson 3.23.2)
- dirac (version 19.0, 21.1, 22.0)
- molcas (version )

## How to setup

以下のコマンドを実行するとビルドが実行されます

```sh
 sh setup.sh
```
