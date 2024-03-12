# SINETStream Bridge

## 概要

SINETStream BridgeはSINETStreamライブラリを用いてメッセージブローカー間でメッセージを中継するプログラムである。

詳しい利用方法はユーザガイドを参照のこと。

- [SINETStream Bridge ユーザガイド](doc//sinetstream-bridge-userguide.md)

## 利用方法

まずSINETSteam Bridge用の設定ファイル `./.sinetstream_config.yml` を作成する。
書式は [ユーザガイド](doc//sinetstream-bridge-userguide.md) を参照のこと。

起動は、設定ファイルを置いたディレクトリで起動スクリプト `sinetstream-bridge` を実行する。

```
bin/sinetstream-bridge
```

ログは標準エラー出力にでる。
より詳細なログが必要なときは `debug-log.prop` を使うよう指定して起動する。

```
bin/sinetstream-bridge --log-prop-file src/main/resources/jp/ad/sinet/stream/bridge/debug-log.prop
```

