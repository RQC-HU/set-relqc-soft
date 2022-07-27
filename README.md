# Softwares setup relativistic quantum chemistry

相対論的量子化学計算プログラムのビルドを行うスクリプトです

## Pre-requirements

ビルドにあたっては以下のコマンド、ツールがセットアップされていることを前提とします

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

- MOLCAS
  - license.dat(ライセンスファイル)が./molcasディレクトリもしくは$HOME/.Molcasディレクトリ直下に配置されていること
- Intel(R) Fortran, C, C++ compiler, Math kernel library
  - [Intel(R) Fortran, C, C++ compiler](https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)
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
(SETUP_NPROCSの値は6以上を推奨します)  
(SETUP_NPROCSの値が不正であるか、設定されていない場合SETUP_NPROCSの値は1になります)

```sh
 SETUP_NPROCS=使用コア数 sh setup.sh
 # (e.g.)
 SETUP_NPROCS=8 sh setup.sh
```
