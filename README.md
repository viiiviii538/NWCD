# NWC-densetsu

ネットワーク診断ツールの試作プロジェクトです。Flutter デスクトップアプリとして開発します。

## 必要なソフトウェア

本ツールは内部で Python スクリプトを呼び出し、LAN 内デバイスの探索には
`arp-scan` または `nmap` を利用します。`arp-scan` が無い環境では `nmap`
のみで動作するため、Windows では追加のインストールは必須ではありません。
Python **3.10 以上** といずれかのコマンドがインストールされていることを確認して
ください。Python 3.10 未満では `list[str] | None` などの最新の型ヒント構文が
解釈できず、付属スクリプトが実行できません。
ネットワーク速度計測には `speedtest-cli` を使用します。
LAN セキュリティ診断 (`lan_security_check.py`) では `arp`, `nmap`, `upnpc` など
複数の外部コマンドを利用します。Linux でファイアウォール状態を確認する際は
`ufw` を呼び出します。これらのユーティリティが存在しない場合、該当する
チェックは自動的にスキップされます。

また、`nmap` や `arp-scan` の実行ファイルがシステムの `PATH` に含まれている必要
があります。次のように入力して認識されるか確認してください。

```bash
nmap -V  # または Windows では where nmap
```

コマンドが見つからない場合は、インストール先のディレクトリを `PATH` に追加して
ください。

### 主要ツールのインストール例

以下は `nmap`, `arp-scan`, `speedtest-cli` を導入する際の主なコマンド例です。

```bash
# Debian/Ubuntu
sudo apt install nmap arp-scan speedtest-cli graphviz wkhtmltopdf

# Fedora
sudo dnf install nmap arp-scan speedtest-cli graphviz wkhtmltopdf

# macOS (Homebrew)
brew install nmap arp-scan speedtest-cli graphviz wkhtmltopdf

# Windows
winget install -e --id Nmap.Nmap      # nmap
winget install -e --id Graphviz.Graphviz  # graphviz
winget install -e --id wkhtmltopdf.wkhtmltopdf  # wkhtmltopdf
pip install speedtest-cli      
# arp-scan は Windows 版が存在しないため省略
```


## 開発の始め方

1. [Flutter](https://flutter.dev/) 環境を用意します。
2. リポジトリをクローン後、`flutter pub get` を実行します。
3. `flutter run -d windows` などデスクトップターゲットで起動します。

## Python ライブラリのインストール / Dependency Setup

付属の Python スクリプトには `geoip2`, `psutil`, `graphviz`, `pdfkit`, `weasyprint`
などのモジュールが必要です。リポジトリのルートで次のコマンドを実行し、必要な
ライブラリをまとめてインストールしてください:

```bash
pip install -r requirements.txt
```
PDF 生成を行う場合は、`pdfkit` が利用する `wkhtmltopdf` または `weasyprint` の
いずれかがシステムにインストールされている必要があります。どちらも存在しない
環境では `--pdf` オプションを指定しても PDF 出力はスキップされます。

## できること
- **LANスキャン** ボタンを押すと `arp-scan` または `nmap` を使って LAN 内のデバイスを検出し、見つかった各 IP へ自動で診断を実行します。
- 診断中は "診断中..." の表示と、各ホスト進捗に加えて全体バーで完了状況が分かります。
- 結果はスクロール可能な領域に表示され、セキュリティスコアは大きな文字で示されます。
- 診断結果画面右上の「レポート保存」ボタンを押すと、`report_YYYY-MM-DD_HH-MM.txt` という名前のファイルが出力されます。
- 実施する診断内容は次のとおりです。
  - `ping` 実行結果
  - 代表的なポートへの接続可否
  - ドロップダウンから Quick / Full などのポートプリセットを選択可能
  - SSL 証明書の発行者と有効期限
  - DNS の SPF レコード
  - ネットワーク速度測定 (download/upload/ping) の結果表示
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

## セキュリティスコア計算

`security_score.py` スクリプトはポート数や GeoIP、UPnP など複数の指標をまとめた
JSON を読み込み、10.0 を満点とするセキュリティスコアを計算します。値が小さいほど危険度が高いことを示します。入力例は以下の通りです。

```json
[
  {"device": "192.168.1.10", "danger_ports": 1, "geoip": "RU", "ssl": false, "open_port_count": 3},
  {"device": "192.168.1.20", "danger_ports": 0, "geoip": "US", "ssl": true, "open_port_count": 2}
]
```

実行例:

```bash
python security_score.py devices.json
```

RDP ポート (3389) が開いている、またはロシアなど危険国との通信がある場合は、赤字で警告が表示されます。

## 0.0〜10.0 スコアリングシステム

スコアは high_risk, medium_risk, low_risk の件数を用いて
`10 - high*HIGH_WEIGHT - medium*MEDIUM_WEIGHT - low*LOW_WEIGHT` で計算されます。
各定数のデフォルト値は `security_score.py` で次のように定義されています。

```python
HIGH_WEIGHT = 0.7
MEDIUM_WEIGHT = 0.3
LOW_WEIGHT = 0.2
```
数値が小さいほどリスクが高く、0 から 10 の範囲に丸められます。

例として Python から直接呼び出す場合は次の通りです。

```python
from security_score import calc_security_score

result = calc_security_score({
    "danger_ports": 1,
    "geoip": "RU",
    "ssl": False,
    "open_port_count": 3,
})
print(result["score"], result["high_risk"])
```


## HTML レポート生成


`generate_html_report.py` を使うと、デバイス情報から HTML 形式のレポートを作成できます。
`--pdf` オプションを指定すると、`pdfkit` または `weasyprint` が利用可能な環境では PDF も生成します。
PDF 出力には `wkhtmltopdf` (pdfkit) もしくは `weasyprint` をインストールしておく必要があります。

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
LAN スキャン時に計測され、結果は画面にも表示されます。

```bash
python network_speed.py
```

出力例:

```json
{"download": 100.0, "upload": 20.0, "ping": 15.0}
```

## 外部通信レポート

`external_ip_report.py` は現在の外部接続を列挙し、ドメイン名と国情報を表示します。
ネットワーク接続情報を取得するため `psutil` の `net_connections()` を利用しており、
環境によっては管理者権限（`sudo`）での実行が必要になる場合があります。

```bash
python external_ip_report.py
```

GeoIP データベースを指定する場合は `--geoip-db` オプションを利用してください。

## LANセキュリティ診断

`lan_security_check.py` を実行すると、ARPスプーフィングやUPnP有効機器の有無、
複数DHCPサーバなど LAN 内のリスクを確認できます。ローカルサブネットは自動検出
されますが、引数で `192.168.0.0/24` など任意の範囲を指定することもできます。結果
は JSON 形式で出力され、UTMで防御可能な項目も一覧化されます。さらに、外部通信
先の国別件数が `country_counts` フィールドに含まれます。

```bash
python lan_security_check.py  # 自動検出されたサブネットを使用
python lan_security_check.py 10.0.0.0/24  # サブネットを指定する場合
```

## Network Topology

`generate_topology.py` を使うと `discover_hosts.py` や `lan_port_scan.py` の JSON 出力からネットワーク図を生成できます。
この機能を利用するには Graphviz の実行ファイルが必要です。`sudo apt install graphviz` などでインストールしてください。

```bash
python generate_topology.py scan_results.json -o topology.svg
```

`-o` には `.png`, `.svg`, `.dot` のいずれかを指定します。何も指定しない場合は `topology.svg` が生成されます。
生成した SVG はアプリ内で拡大・縮小できるインタラクティブビューアーで閲覧できます。

## スキャン実行時の注意

本ツールによるホスト探索やポートスキャンは、運用者が明示的な許可を得たネットワークでのみ実行してください。許可なく他者のネットワークをスキャンすると、不正アクセス禁止法などの法令に抵触し、民事・刑事上の責任を問われる可能性があります。

## カラー表示の切り替え

Python スクリプトやアプリでは出力にカラー表示を利用しています。端末で色を無効化したい場合は環境変数 `NWCD_NO_COLOR=1` を設定してください。Flutter アプリではビルド時に `--dart-define=NWCD_USE_COLOR=false` を指定するとグレースケールで表示されます。

## テスト

Python スクリプトのユニットテストは `test` ディレクトリにあります。テストを実行
する前に、`requirements.txt` に記載された依存ライブラリをインストールしておいて
ください。特に `graphviz` パッケージが無い環境ではネットワーク拓撲図関連のテスト
がスキップされます。

```bash
pip install -r requirements.txt  # または ./install_requirements.sh
```

すべてのテストを実行する場合は `pytest` を利用します。

```bash
pytest
```

`test` ディレクトリで `pytest` を実行しても動作するよう、`conftest.py` で
`PYTHONPATH` を調整しています。

Flutter ウィジェットテストを実行するには次のコマンドを利用します。

```bash
flutter test
```

## リリースバンドルに含めるファイル

デスクトップ版を配布する際は、リポジトリ直下の Python スクリプトをすべて実行
ファイルと同じディレクトリに配置してください。`flutter build windows` や
`flutter build linux` で作成したバンドルにこれらを含めないと、アプリから外部ス
クリプトを呼び出せなくなります。主なスクリプトは次の通りです。

- `discover_hosts.py`
- `port_scan.py`
- `lan_port_scan.py`
- `network_speed.py`
- `security_report.py`
- `generate_html_report.py`
- `generate_topology.py`

## 貢献

詳しい貢献方法は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
