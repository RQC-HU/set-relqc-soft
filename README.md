# Setup relativistic quantum chemistry softwares (set-relqc-soft)

相対論的量子化学計算プログラムのビルドを行うスクリプトです

## Pre-requirements

ビルドにあたっては以下のコマンド、ツールがセットアップされていることを前提とします

- Intel(R) Fortran, C, C++ compiler, Math kernel library
  - [Intel(R) Fortran, C, C++ compiler](https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)
  - [Intel(R) Math kernel library](https://www.intel.com/content/www/us/en/develop/documentation/get-started-with-mkl-for-dpcpp/top.html)

- インターネットアクセス
  - いくつかのツールはインターネットアクセスを必要とするため、セットアップを行うサーバからインターネットへのアクセスが可能である必要があります

- Environment Modules(必須ではないが推奨)
  - Environment Modulesを使っていないと、セットアップ後DIRACなどのソフトウェア実行前に毎回OpenMPIなどの依存のあるソフトウェアのパスを設定しないといけなくなるのでmoduleコマンドを使える状態にすることを推奨します
  - [公式サイトはこちら](http://modules.sourceforge.net/)
  - セットアップ後は\$HOME/.bashrcにmodule use --append "/セットアップしたユーザのホームディレクトリ/modulefiles"を記述すればmodule load dirac/22.0などのコマンドだけでDIRACのパスが設定されpamコマンドが使えるようになります(GitやCMakeも同様です)

  ```sh
    module use --append "/home/noda/modulefiles"
    module load dirac/22.0
  ```

- MOLCAS(ソースコードとライセンスファイル)
  - license.dat(ライセンスファイル)およびソースコードの圧縮ファイル(e.g. molcas84.tar.gz)がこのREADMEファイル直下の./molcasディレクトリにあることを前提とします

- UTChem(ソースコードとパッチ)
  - このREADMEファイル直下の./utchemディレクトリにUTChemのソースコードの圧縮ファイルutchem*.tar* (\*は0文字以上の任意の名前)があることを前提とします
  - ./utchem/patches ディレクトリ下にga_patch, global_patch, makefile.h.patchがあることを前提とします

## ビルドされるソフトウェア

- [git](https://git-scm.com/) (version 2.37.1)
- [cmake](https://cmake.org/) (verson 3.23.2)
- [OpenMPI](https://www.open-mpi.org/) (version 3.1.0 4.1.2)
- [dirac](http://diracprogram.org) (version 19.0, 21.1, 22.0)
- [molcas](https://molcas.org)
- [UTChem](http://ccl.scc.kyushu-u.ac.jp/~nakano/papers/lncs-2660-84.pdf)

## How to setup

以下のコマンドを実行するとビルドが実行されます  

```sh
 INSTALL_PATH=/path/to/install SETUP_NPROCS=使用コア数 INSTALL_ALL=YES sh setup.sh
 # (e.g.)
 INSTALL_PATH=$HOME/build/softwares SETUP_NPROCS=12 INSTALL_ALL=YES sh setup.sh
 # 全体のビルドのログを取りたい場合
 INSTALL_PATH=/path/to/install SETUP_NPROCS=12 INSTALL_ALL=YES sh setup.sh | tee setup.log
 # DIRAC, MOLCAS, UTChemをインストールするかどうか指定したいとき(例: UTChemをインストールしない場合)
 INSTALL_PATH=/path/to/install SETUP_NPROCS=12 INSTALL_DIRAC=YES INSTALL_MOLCAS=YES INSTALL_UTChem=NO sh setup.sh
```

- 環境変数INSTALL_DIRAC, INSTALL_MOLCAS, INSTALL_UTChemは環境変数INSTALL_ALL=YESとしたときは指定する必要はありません  
- INSTALL_ALL, INSTALL_DIRAC, INSTALL_MOLCAS, INSTALL_UTChemの指定が不十分なときは以下のようなインタラクティブな質問に答える必要があります

```sh
Do you want to install DIRAC? (y/N)
```

- 環境変数INSTALL_PATHを設定すると指定ディレクトリ下にインストールされます。指定しないとデフォルトの\$HOME/softwareにインストールされます
- INSTALL_PATHで指定しているディレクトリはインストール時**存在していない**必要があります(上書きを防ぐための仕様です)
- 環境変数SETUP_NPROCSはビルドに使用するプロセス数を指定します。値が不正であるか指定しない場合はデフォルトの1プロセスになります(SETUP_NPROCSの値は6以上を推奨します)
- 各ソフトウェアのログは自動的にlogファイルとして書き込まれます

### Molcasのテスト

- Molcasについては、テストコマンドをシェルスクリプト内で実行すると実行されずに終わってしまうのでビルド後に手動でテストを行ってください
- 例として以下のようなコマンドでテストができます

```sh
# 3並列で並列実行のテストをする
molcas verify --parallel 3
```

- コマンドについての詳細は molcas verify --help を参照してください

### インストール時に存在しているディレクトリ上にソフトウェアをインストールしたい場合

  上書きされる可能性があることを承知した上で、すでに存在するディレクトリをINSTALL_PATHに指定したい場合は環境変数OVERWRITEをYESに設定してください

  ```sh
  OVERWRITE=YES INSTALL_PATH=$HOME/softwares SETUP_NPROCS=12 sh setup.sh
  ```

  OVERWRITEをYESにした場合スクリプトのはじめに以下のような質問が出るので、上書きされる可能性について理解して了承している場合yを選択してください

  ```sh
  !!!!!!!!!!!!!!!!!!!!! Warning: OVERWRITE option selected YES !!!!!!!!!!!!!!!!!!!!!
  Warning: OVERWRITE option selected YES.  may overwrite the existing path! /path/to/install.
  If you want to keep the existing path, please set OVERWRITE not to YES.
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  Do you want to set OVERWRITE option selected YES? (y/N)
  ```

  以上でインストール時に存在しているディレクトリにもソフトウェアをインストールすることができるようになります
