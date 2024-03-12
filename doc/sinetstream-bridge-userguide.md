<!--
Copyright (C) 2023 National Institute of Informatics

Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

# SINETStream Bridge ユーザガイド

## 概要

SINETStream BridgeはSINETStreamライブラリを用いてメッセージブローカー間でメッセージを中継するプログラムである。


## インストール

SINETStream Bridgeの実行にはJava runtime (version 11以降)が必要である。

https://github.com/nii-gakunin-cloud/sinetstream-bridge/releases
からsinetstream-xxx.zipをダウンロードし展開する。

ディレクトリ `sinetstream-bridge-xxx` が作成されているはずである。
SINETStream Bridgeが実行可能なのを確認する。

```
$ sinetstream-bridge-xxx/bin/sinetstream-bridge --help
usage: sinetstream-bridge [--option ...]
 -f,--config-file <FILE>      specify the config file
 -h,--help                    this help
 -lp,--log-prop-file <FILE>   read the specfied logging proerties file
 -s,--service <SERVICE>       specify the service name
```

## 設定ファイル

設定ファイルはYAMLでSINETStreamとおなじ形式である。
ただし設定ファイルのフォーマットはバージョン2のみ受け付ける。

````
# 例
header:
    version: 2  # v2のみ
config:
    mybridge:         # この名前は任意
        type: bridge  # ブリッジの設定項目であることを示している
        bridge:
            reader:
                - upstream-1    # 上流側のSINETStreamサービス名を指定
            writer:
                - downstream-1  # 下流側のSINETStreamサービス名を指定
    upstream-1:
        value_type: text
        type: mqtt
        brokers: broker_mqtt_1
        topic: topic-mqtt-1
    downstream-1:
        value_type: text
        type: kafka
        brokers: broker_kafka_1
        topic: topic-kafka-1
````

メッセージングシステムのタイプとして `type: bridge` を指定することでブリッジの設定項目であることを指示する。
ブリッジの設定は `bridge:` の中に記述する。


### ブリッジの設定項目

* `reader:` (文字列のリスト)
    * 上流側になるSINETSTream readerのサービス名を列挙する。(複数可)
* `writer:` (文字列のリスト)
    * 下流側になるSINETSTream writerのサービス名を列挙する。(複数可)
    * 注意: readerのサービスとwriterのサービスが重複するとwriterの出力メッセージがreaderの入力メッセージとして還流してメッセージループを形成してしまう。
* `retry:`
    * 再接続時の動作を指定する。
    * `connect_max:` (正整数)
        * デフォルト: `3`
        * 上流下流のブローカとの接続に異常が発生した場合に再接続するが、試行回数の上限を指定する。
        * 試行回数は個々のSINETStreamサービスごとにカウントされる。
        * 接続失敗が連続して指定回数起った場合はそのSINETStreamサービスは停止する。
    * `connect_min_delay:` (正整数)
        * デフォルト: `1`
        * 始めての再接続での待ち時間(秒)を指定する。
        * 再接続に失敗するごとに待ち時間は2倍される。
        * 接続に成功すると待ち時間はretry_connect_min_delayに戻る。
    * `connect_max_delay:`
        * デフォルト: `64`
        * 再接続での待ち時間(秒)の上限を指定する。
* `report:` (文字列)
    * ブリッジのログメッセージは標準エラー出力に出力されるが、同じものをこのSINETStreamサービスにも送信できる。
    * 省略した場合は送信されない。(標準エラー出力のみ)
* `max_qlen:` (正整数)
    * readerとwriterの間の転送待ちメッセージ数の上限を指定する。
    * 転送待ちメッセージが上限に達するとreaderは空きができるまで待たされる。
    * デフォルト: `1`


## 実行方法

`sinetstream-bridge` を実行すると、カレントディレクトリの設定ファイル `.sinetstream_config.yml` を読んで中継を始める。
初期化時に上流下流のメッセージングサービスに接続できなかった場合はブリッジは異常終了する。

中継動作中に上流下流のメッセージングサービスとの接続に異常が発生すると指定回数だけ再接続を試みる。
再接続が成功しなかった場合はそのSINETStreamサービスのみ停止する。

上流側のSINETStreamサービスがすべて停止した場合はブリッジが異常終了する。
同様に
下流側のSINETStreamサービスがすべて停止した場合はブリッジが異常終了する。


### コマンドライン・オプション

書式: `sinetstream-bridge` *[options]*

* `-s` *SERVICE*, `--service` *SERVICE*
    * ブリッジの設定項目を指定する。
    * 省略した場合には設定ファイルに `type: bridge` の設定が一つしかない場合に限り、これがブリッジの設定として使われる。
* `-f` *FILE*, `--config-file` *FILE*
    * カレントディレクトリの `.sinetstream_config.yml` のかわりに、指定された *FILE* を設定ファイルとして読み込む。
* `-lp` *FILE*, `--log-prop-file` *FILE*
    * ログライブラリのパラメータが入ったプロパティファイルを読み込む。
    * 指定しなかった場合は WARNING レベル以上のログが標準エラー出力に出力される。
        * 詳しくは: sinetstream-bridge/src/main/resources/jp/ad/sinet/stream/bridge/log.prop


## ログメッセージ

主要なログメッセージには次のようなものがある:

* `SINETStream-Bridge:<ファイル名>: ERROR IN THE CONFIG FILE`
    * 設定ファイルに問題がある。
* `SINETStream-Bridge:<bridgeのSINETStreamサービス名> CONNECTION ERROR`
    * 上流下流のメッセージングサービスに接続できなかった。
* `SINETStream-Bridge:<bridgeのSINETStreamサービス名> STARTED`
    * ブリッジが正常に起動した。(中継動作中)
* `SINETStream-Bridge:<bridgeのSINETStreamサービス名> TERMINATED`
    * ブリッジが異常終了した。
* `SINETStream-Bridge:<reader/writerのSINETStreamサービス名>: DISCONNECTED`
    * メッセージングサービスとの接続に異常が発生した。(再接続モードに入る)
* `SINETStream-Bridge:<reader/witerのSINETStreamサービス名>: RECONNECTING`
    * メッセージングサービスに再接続を試行中。
* `SINETStream-Bridge:<reader/writerのSINETStreamサービス名>: RECONNECTED`
    * メッセージングサービスと再接続した。(中継動作に戻る)
* `SINETStream-Bridge:<reader/writerのSINETStreamサービス名>: CONNECTION ERROR`
    * メッセージングサービスへの再接続が失敗した。


## 付録

### 構築手順

ソースコードから構築するには、まずSINETStream Bridgeのソースコード一式をgithubなどからとってくる。

```
$ git clone https://github.com/nii-gakunin-cloud/sinetstream-bridge.git
```

gradleをつかってビルドする。

```
$ cd sinetstream-bridge
$ ./gradlew build
```

ディレクトリ `build/distributions` の下に実行形式一式 `sinetstream-bridge-xxx.tar` ができているので
これを展開する。

```
$ tar xf build/distributions/sinetstream-bridge-xxx-SNAPSHOT.tar
```

ディレクトリ `sinetstream-bridge-xxx` が作成されているはずである。
SINETStream Bridgeが実行可能なのを確認する。

```
$ sinetstream-bridge-xxx/bin/sinetstream-bridge --help
usage: sinetstream-bridge [--option ...]
 -f,--config-file <FILE>      specify the config file
 -h,--help                    this help
 -lp,--log-prop-file <FILE>   read the specfied logging proerties file
 -s,--service <SERVICE>       specify the service name
```

### 中継時にメッセージを改変する方法

`src/main/java/jp/ad/sinet/stream/bridge/BridgeServer.java` に３つのメソッド
`BridgeServer.convertSample1`, `BridgeServer.convertSample2`, `BridgeWriter.convertSample3`
が定義してある:
* `BridgeServer.convertSample1`: BridgeReaderが受信したメッセージを改変するポイント
* `BridgeServer.convertSample2`: 受信したメッセージをBridgeWriterに渡すときに改変するポイント
* `BridgeWriter.convertSample3`: 転送メッセージをBridgeWriterが送信する前に改変するポイント


#### 例

````
// 受信時に文字列を大文字に変換する
Message convertSample1(Message msg, BridgeReader reader) {
    if ((boolean) reader.serviceParams.get("convertSample1")) {
        String value = (String) msg.getValue();
        value = value.toUpperCase();
        return new Message(value,
                           msg.getTopic(),
                           msg.getTimestampMicroseconds(),
                           msg.getRaw());
    } else {
        return msg;
    }
}
````

````
// 1/nの確率でメッセージを転送しない
Message convertSample2(Message msg, BridgeWriter writer) {
    int n = (int) writer.serviceParams.get("convertSample2");
    if (n < 0)
        return msg; // THRU
    int i = (int) writer.serviceParams.getOrDefault("convertSample2count", 0);
    i++;
    writer.serviceParams.put("convertSample2count", i);
        return i % n == 0 ? null  // DROP
                          : msg;
}
````

````
// 送信時に文字列を小文字に変換する
Message convertSample3(Message msg) {
    if ((boolean) this.serviceParams.get("convertSample3")) {
        String value = (String) msg.getValue();
        value = value.toLowerCase();
        return new Message(value,
                           msg.getTopic(),
                           msg.getTimestampMicroseconds(),
                           msg.getRaw());
    } else {
        return msg;
    }
}
````

````
# .sinetstream_config.yml
header:
    version: 2
config:
    mybridge:
        type: bridge
        bridge:
            reader:
                - upstream-1
            writer:
                - downstream-1
                - downstream-2
    upstream-1:
        value_type: text
        type: mqtt
        brokers: mqtt_broker
        topic: topic-1
        convertSample1: true  # toupper
    downstream-1:
        value_type: text
        type: mqtt
        brokers: mqtt_broker
        topic: topic-2
        convertSample2: 4  # drop 1/4
        convertSample3: true  # tolower
    downstream-2:
        value_type: text
        type: mqtt
        brokers: mqtt_broker
        topic: topic-3
        convertSample2: -1  # thru
        convertSample3: false  # dont tolower
````

````
         topic-1  ______  topic-2
[Writer]-------->|      |----------------->[Reader]
 "Hoge1"         |Broker|                   "hoge1"
 "Hoge2"         |      | topic-3           "hoge2"
 "Hoge3"         |______|-------->[Reader]  "hoge3"
 "Hoge4"           |  A            "HOGE1"
            topic-1|  |topic-2,    "HOGE2"
                  _V__|_topic-3    "HOGE3"
                 |      |          "HOGE4"
                 |Bridge|
                 |______|
````
