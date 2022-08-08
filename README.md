# Setup relativistic quantum chemistry softwares (set-relqc-soft)

相対論的量子化学計算プログラムのビルドを行うスクリプトです

## Pre-requirements

ビルドにあたっては以下のコマンド、ツールがセットアップされていることを前提とします
またセットアップ不要なプログラムがある場合、スクリプトの最初に以下のような質問が表示されるので、yまたはY**以外**を選んでください(インストールがスキップされます)

```sh
Do you want to install MOLCAS? (y/N)
```

- インターネットアクセス
  - いくつかのツールはインターネットアクセスを必要とするため、セットアップを行うサーバからインターネットへのアクセスが可能である必要があります

- Environment Modules(必須ではないが推奨)
  - セットアップされていない場合はPATHをスクリプト内で自動的に解決しますが、DIRACなどの実行時に毎回OpenMPIのパスを設定しないといけなくなるのでmoduleコマンドを使える状態にすることを推奨します
  - [公式サイトはこちら](http://modules.sourceforge.net/)
  - 他のPre-requirementsがEnvironment Modulesを使ってセットアップされている場合、スクリプト内でmodule purgeをしているため、setup.shのmodule purgeのあとでmodule loadをするようにスクリプトを変更してから実行してください
  (例: Intel(R) FortranやMKLをEnvironment Modulesを使ってintel-fortran及びmklという名前でセットアップしている場合)

  ```sh
    # Clean modulefiles
    module purge
    module load intel-fortran
    module load mkl
  ```

  - セットアップ後は\$HOME/.bashrcにmodule use --append "/セットアップしたユーザのホームディレクトリ/modulefiles"を記述すればmodule load DIRAC/21.1などのコマンドだけでDIRACのパスが設定されpamコマンドが使えるようになります(GitやCMakeも同様です)

  ```sh
    module use --append "/home/noda/modulefiles"
    module load DIRAC/21.1
  ```

- MOLCAS(ソースコードとライセンスファイル)
  - license.dat(ライセンスファイル)およびソースコードの圧縮ファイル(e.g. molcas84.tar.gz)がこのREADMEファイル直下の./molcasディレクトリにあることを前提とします
- Intel(R) Fortran, C, C++ compiler, Math kernel library
  - [Intel(R) Fortran, C, C++ compiler](https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)
  - [Intel(R) Math kernel library](https://www.intel.com/content/www/us/en/develop/documentation/get-started-with-mkl-for-dpcpp/top.html)

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
 INSTALL_PATH=/path/to/install SETUP_NPROCS=使用コア数 sh setup.sh
 # (e.g.)
 INSTALL_PATH=$HOME/build/softwares SETUP_NPROCS=12 sh setup.sh
 # 全体のビルドのログを取りたい場合
 INSTALL_PATH=/path/to/install SETUP_NPROCS=12 sh setup.sh | tee setup.log
```

- 環境変数INSTALL_PATHを設定すると指定ディレクトリ下にインストールされます。指定しないとデフォルトの\$HOME/softwareにインストールされます
- INSTALL_PATHで指定しているディレクトリはインストール時**存在していない**必要があります(上書きを防ぐための仕様です)
- 環境変数SETUP_NPROCSはビルドに使用するプロセス数を指定します。値が不正であるか指定しない場合はデフォルトの1プロセスになります(SETUP_NPROCSの値は6以上を推奨します)
- 各ソフトウェアのログは自動的にlogファイルとして書き込まれますが、全体のログを取りたい場合は必ずteeコマンドを用いてログを取ってください(インタラクティブな部分があるので sh setup.sh > setup.log 2>&1 のようなログの取り方だと正常にスクリプトが実行されません)



- スクリプトが始まるとUTChem,DIRAC,Molcasについては以下のような質問が表示されるので、yまたはYのあとEnter keyを打つとインストールされます(それ以外はどんな入力が行われてもインストールされません)

```sh
Do you want to install DIRAC? (y/N)
```
### Molcasのテスト

- Molcasについては、テストコマンドをシェルスクリプト内で実行すると実行されずに終わってしまうのでビルド後に手動でテストを行ってください
- 例として以下のようなコマンドでテストができます

```sh
# 3並列で並列実行のテストをする
molcas verify --parallel 3
```

- コマンドについての詳細は molcas verify --help を参照してください

### UTChemのテスト

- スクリプト内でtests/TCEを含むディレクトリはテストをしていますが、自動的にテストをやったうえで評価してくれる仕組みはUTChemには備わっていません
- 従って適当なテストを使って確認をするなどしてください

### インストール時に存在しているディレクトリ上にソフトウェアをインストールしたい場合

  上書きされる可能性があることを承知した上で、すでに存在するディレクトリをINSTALL_PATHに指定したい場合は環境変数OVERWRITEをYESに設定してください

  ```sh
  OVERWRITE=YES INSTALL_PATH=$HOME/softwares SETUP_NPROCS=12 sh setup.sh
  ```

  OVERWRITEをYESにした場合スクリプトのはじめに以下のような質問が出るので、上書きのことについて理解して了承している場合yを選択してください

  ```sh
  Warning: OVERWRITE option selected YES.  may overwrite the existing path! /path/to/install.
  If you want to keep the existing path, please set OVERWRITE not to YES.
  Do you want to continue? (y/N)
  ```

  以上でインストール時に存在しているディレクトリにもソフトウェアをインストールすることができるようになります
