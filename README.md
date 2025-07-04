# NWC-densetsu

ネットワーク診断ツールの試作プロジェクトです。Flutter デスクトップアプリとして開発します。

## 必要なソフトウェア

本ツールは内部で Python スクリプトを呼び出し、LAN 内デバイスの探索には
`arp-scan` または `nmap` を利用します。`arp-scan` が無い環境では `nmap`
のみで動作するため、Windows では追加のインストールは必須ではありません。
Python (3 系) といずれかのコマンドがインストールされていることを確認して
ください。

また、`nmap` や `arp-scan` の実行ファイルがシステムの `PATH` に含まれている必要
があります。次のように入力して認識されるか確認してください。

```bash
nmap -V  # または Windows では where nmap
```

コマンドが見つからない場合は、インストール先のディレクトリを `PATH` に追加して
ください。

## 開発の始め方

1. [Flutter](https://flutter.dev/) 環境を用意します。
2. リポジトリをクローン後、`flutter pub get` を実行します。
3. `flutter run -d windows` などデスクトップターゲットで起動します。

## Python ライブラリのインストール / Dependency Setup

付属の Python スクリプトには `geoip2`, `psutil`, `pdfkit`, `weasyprint` などの
モジュールが必要です。リポジトリのルートで次のコマンドを実行し、必要なライブラリ
をまとめてインストールしてください:

```bash
pip install -r requirements.txt
```

## できること
- **LANスキャン** ボタンを押すと `arp-scan` または `nmap` を使って LAN 内のデバイスを検出し、見つかった各 IP へ自動で診断を実行します。
- 診断中は "診断中..." の表示とプログレスインジケータが現れます。
- 結果はスクロール可能な領域に表示され、セキュリティスコアは大きな文字で
  示されます。
- 診断結果画面右上の「レポート保存」ボタンを押すと、`report_YYYY-MM-DD_HH-MM.txt` という名前のファイルが出力されます。
- 実施する診断内容は次のとおりです。
  - `ping` 実行結果
  - 代表的なポートへの接続可否
  - SSL 証明書の発行者と有効期限
  - DNS の SPF レコード
  - ネットワーク速度測定 (download/upload/ping)
  - これらを基にしたセキュリティスコア（0〜10）

この最小構成を起点に、今後の機能追加を行っていきます。

## ポートスキャン


`port_scan.py` スクリプトでは `nmap` を利用して指定したポート、またはポート指定が
ない場合は全ポート (`-p-`) をスキャンし、結果を JSON 形式で出力します。`-sV` による
サービスバージョン検出や `-O` による OS 推定、さらに任意の NSE スクリプトを指定でき
るようになりました。LAN スキャン機能で各ホストの診断に使われるほか、次のように単体
でも実行できます。

```bash
python port_scan.py <host> [port_list] [--service] [--os] [--script vuln]
```

## LAN デバイス一覧取得

`discover_hosts.py` は `arp-scan --localnet` または `nmap -sn` を実行して LAN 内の IP アドレス、MAC アドレス、ベンダー名を収集し、JSON 形式で出力します。アプリの "LANスキャン" ボタンを押すとこのスクリプトが実行され、結果が表に表示されます。ベンダー名取得にはインターネット接続が必要ですが、同じディレクトリに `oui.txt` (OUI 一覧) を置けばオフラインでも利用できます。

### PATH の確認

`discover_hosts.py` が外部ツールとして呼び出す `nmap` または `arp-scan` は PATH に含まれている必要があります。次のコマンドで認識されるか確認してください。

```bash
nmap -V # または arp-scan --version
```

表示されない場合はインストール先を PATH に追加してください。


## LAN + Port Scan

`lan_port_scan.py` は上記 2 つの機能を組み合わせ、LAN 内の各ホストを自動で検出した後、指定したポート (未指定時は主要ポート) をスキャンします。次のように実行します。

```bash
python lan_port_scan.py --subnet 192.168.1.0/24 --ports 22,80 --service --os
```

出力例:

```json
[
  {
    "ip": "192.168.1.10",
    "mac": "AA:BB:CC:DD:EE:FF",
    "vendor": "Acme",
    "ports": [
      {"port": "22", "state": "open", "service": "ssh"}
    ]
  }
]
```

## 危険度スコア計算

`risk_score.py` スクリプトは、各機器の開放ポートと通信先の国情報を入力とし、0〜10 の危険度スコアを算出します。入力ファイルは次のような JSON 配列を想定しています。

```json
[
  {"device": "192.168.1.10", "open_ports": ["3389"], "countries": ["RU"]},
  {"device": "192.168.1.20", "open_ports": ["80", "22"], "countries": ["US"]}
]
```

実行例:

```bash
python risk_score.py devices.json
```

RDP ポート (3389) が開いている、またはロシアなど危険国との通信がある場合は、赤字で警告が表示されます。

## 0.0〜10.0 スコアリングシステム


`calc_risk_score` 関数は開放ポートと通信国の情報から 0.0〜10.0 のスコアを計算します。RDP(3389) は 4 点、445 番は 3 点、23 番は 2 点、22 番は 1.5 点、21 番と 80 番は 1 点、443 番は 0.5 点が加算されます。未定義のポートは 0.5 点と低めに加算され、ポート由来の合計は最大 6 点です。国コードの評価では、`RU`、`CN`、`KP` といった危険国は 4 点、上記以外で安全国（JP, US, GB, DE, FR, CA, AU）に該当しない国は 0.8 点ずつ加算され、こちらは 4 点が上限となります。UTM を導入している場合は `has_utm=True` を指定すると最終スコアが 0.8 倍になります。


例として Python から直接呼び出す場合は次の通りです。

```python
from risk_score import calc_risk_score

score, warnings = calc_risk_score(
    open_ports=["3389", "80"],
    countries=["RU", "JP"],
    has_utm=False,
)
print(score, warnings)
```


## HTML レポート生成


`generate_html_report.py` を使うと、デバイス情報から HTML 形式のレポートを作成できます。`--pdf` オプションを指定すると、`pdfkit` または `weasyprint` が利用可能な環境では PDF も生成します。

実行例:

```bash
python generate_html_report.py devices.json -o report.html --pdf
```

入力 JSON の例:

```json
[
  {
    "ip": "192.168.1.10",
    "mac": "AA:BB:CC:DD:EE:FF",
    "vendor": "Acme",
    "open_ports": ["80", "22"],
    "communications": [
      {"ip": "8.8.8.8", "domain": "dns.google", "country": "US"},
      {"domain": "malicious.example", "country": "RU"}
    ]
  }
]
```

## Firewall チェック

`firewall_check.py` は Windows Defender のリアルタイム保護状態と、
Windows または Linux ファイアウォールの有効/無効を確認します。

```bash
python firewall_check.py
```

出力例:

```json
{"defender_enabled": true, "firewall_enabled": true}
```

Windows 以外の環境では `defender_enabled` が `null` となります。

## ネットワーク速度測定

`network_speed.py` は `speedtest-cli` を利用してダウンロード速度、アップロード速度、
および ping を計測します。

```bash
python network_speed.py
```

出力例:

```json
{"download": 100.0, "upload": 20.0, "ping": 15.0}
```

## LANセキュリティ診断

`lan_security_check.py` を実行すると、ARPスプーフィングやUPnP有効機器の有無、
複数DHCPサーバなど LAN 内のリスクを確認できます。ローカルサブネットは自動検出
されますが、引数で `192.168.0.0/24` など任意の範囲を指定することもできます。結果
は JSON 形式で出力され、UTMで防御可能な項目も一覧化されます。

```bash
python lan_security_check.py  # 自動検出されたサブネットを使用
python lan_security_check.py 10.0.0.0/24  # サブネットを指定する場合
```

## スキャン実行時の注意

本ツールによるホスト探索やポートスキャンは、運用者が明示的な許可を得たネットワークでのみ実行してください。許可なく他者のネットワークをスキャンすると、不正アクセス禁止法などの法令に抵触し、民事・刑事上の責任を問われる可能性があります。

## テスト

Python スクリプトのユニットテストは `test` ディレクトリにあります。すべて実行する
場合は以下のコマンドを使用します。

```bash
python -m unittest discover -s test
```

Flutter ウィジェットテストを実行するには次のコマンドを利用します。

```bash
flutter test
```

## 貢献

詳しい貢献方法は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
