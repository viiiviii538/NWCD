# NWCD

ネットワーク診断ツールの試作プロジェクトです。Flutter デスクトップアプリとして開発します。

## 必要なソフトウェア

本ツールは内部で Python スクリプトを呼び出し、LAN 内デバイスの探索には
`nmap` を利用します。Windows でも `nmap` のインストールが必要です。
Python **3.10 以上** といずれかのコマンドがインストールされていることを確認して
ください。Python 3.10 未満では `list[str] | None` などの最新の型ヒント構文が
解釈できず、付属スクリプトが実行できません。
ネットワーク速度計測には `speedtest-cli` を使用します。
LAN セキュリティ診断 (`nwcd_cli.py lan-check`) では `arp`, `nmap`, `upnpc` など
複数の外部コマンドを利用します。Linux でファイアウォール状態を確認する際は
`ufw` を呼び出します。これらのユーティリティが存在しない場合、該当する
チェックは自動的にスキップされます。

また、`nmap` の実行ファイルがシステムの `PATH` に含まれている必要
があります。次のように入力して認識されるか確認してください。

```bash
nmap -V  # または Windows では where nmap
```

コマンドが見つからない場合は、インストール先のディレクトリを `PATH` に追加して
ください。

### 主要ツールのインストール例

以下は `nmap` と `speedtest-cli` を導入する際の主なコマンド例です。

```bash
# Debian/Ubuntu
sudo apt install nmap speedtest-cli graphviz wkhtmltopdf

# Fedora
sudo dnf install nmap speedtest-cli graphviz wkhtmltopdf

# macOS (Homebrew)
brew install nmap speedtest-cli graphviz wkhtmltopdf

# Windows
winget install -e --id Nmap.Nmap      # nmap
winget install -e --id Graphviz.Graphviz  # graphviz
winget install -e --id wkhtmltopdf.wkhtmltopdf  # wkhtmltopdf
pip install speedtest-cli
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
GeoIP 解析を利用するスクリプトでは、上記パッケージに加えて
MaxMind 提供の `GeoLite2-Country.mmdb` データベースが必要です。これは
<https://dev.maxmind.com/geoip/geoip2/geolite2/> からダウンロードし、
リポジトリ直下に配置するか、別の場所に置いた場合は後述の
`--geoip-db` オプションでパスを指定してください。
PDF 生成を行う場合は、`pdfkit` が利用する `wkhtmltopdf` または `weasyprint` の
いずれかがシステムにインストールされている必要があります。どちらも存在しない
環境では `--pdf` オプションを指定しても PDF 出力はスキップされます。

## できること
- **LANスキャン** ボタンを押すと `nmap` を使って LAN 内のデバイスを検出し、見つかった各 IP へ自動で診断を実行します。
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


`nwcd_cli.py port-scan` サブコマンドでは `nmap` を利用して指定したポート、またはポート指定が
ない場合は全ポート (`-p-`) をスキャンし、結果を JSON 形式で出力します。`-sV` による
サービスバージョン検出や `-O` による OS 推定、さらに任意の NSE スクリプトを指定でき
るようになりました。LAN スキャン機能で各ホストの診断に使われるほか、次のように単体
でも実行できます。

```bash
python nwcd_cli.py port-scan <host> [port_list] [--service] [--os] [--script vuln]
```
`--timing` を指定すると `nmap` のタイミングテンプレート (`-T0`~`-T5`) を調整できます。
`--script` を省略した場合は `vuln` スクリプトが自動的に指定され、脆弱性チェックが行われます。
`nmap` 実行には 60 秒のタイムアウトを設けており、極端に時間がかかる場合は自動で終了します。

## LAN デバイス一覧取得

`nwcd_cli.py discover-hosts` は `nmap -sn` を実行して LAN 内の IP アドレス、MAC アドレス、ベンダー名を収集し、JSON 形式で出力します。アプリの "LANスキャン" ボタンを押すとこのスクリプトが実行され、結果が表に表示されます。ベンダー名取得にはインターネット接続が必要ですが、同じディレクトリに `oui.txt` (OUI 一覧) を置けばオフラインでも利用できます。オンライン取得時は 3 秒のタイムアウトを設けており、応答がない場合はベンダー名は空欄となります。
`nmap` によるホスト探索も 60 秒のタイムアウトを設定しており、異常に時間がかかる場合は失敗として扱われます。

### PATH の確認

`nwcd_cli.py discover-hosts` が外部ツールとして呼び出す `nmap` は PATH に含まれている必要があります。次のコマンドで認識されるか確認してください。

```bash
nmap -V
```

表示されない場合はインストール先を PATH に追加してください。

### IPv6 スキャン

`nwcd_cli.py discover-hosts` と `nwcd_cli.py lan-scan` は IPv6 アドレスにも対応しています。IPv6 ネットワークを指定した場合、`nmap` の IPv6 スキャン (`-6` オプション) を自動で利用します。


## LAN + Port Scan

`nwcd_cli.py lan-scan` は上記 2 つの機能を組み合わせ、LAN 内の各ホストを自動で検出した後、指定したポート (未指定時は主要ポート) をスキャンします。次のように実行します。

```bash
python nwcd_cli.py lan-scan --subnet 192.168.1.0/24 --ports 22,80 --service --os
```
`--workers` オプションで同時スキャン数を指定すると、環境に合わせて処理速度を調整できます。

出力例:

```json
[
  {
    "ip": "192.168.1.10",
    "mac": "AA:BB:CC:DD:EE:FF",
    "vendor": "Acme",
    "os": "Microsoft Windows 10",
    "ports": [
      {"port": "22", "state": "open", "service": "ssh"}
    ]
  }
]
```

## セキュリティスコア計算

`security_score.py` スクリプトはポート数や GeoIP、UPnP の有無に加え、ファイアウォール状態や OS の種類、
ARP スプーフィングや複数 DHCP サーバといった LAN リスクも含めた
```json
[
  {"device": "192.168.1.10", "danger_ports": 1, "geoip": "RU", "ssl": "invalid", "open_port_count": 3},
  {"device": "192.168.1.20", "danger_ports": 0, "geoip": "US", "ssl": "valid", "open_port_count": 2}
]
```

実行例:

```bash
python security_score.py devices.json
```

RDP ポート (3389) が開いている、またはロシアなど危険国との通信がある場合は、赤字で警告が表示されます。
インターネットから到達できるポートと、社内ネットワーク内だけで利用されるポートではリスクに大きな差があります。外部に公開されたポートは攻撃の標的となりやすく、システム乗っ取りにつながる可能性が一気に高まります。
特に 445 (SMB) や 3389 (RDP) のような Windows 系サービスを公開していると、脆弱性を突かれて侵入される危険性が極めて高くなります。

`os_version.py` を実行すると現在の Windows バージョンを取得できます。ビルド番号が
22000 以上なら Windows 11 と判定されます。

## 0.0〜10.0 スコアリングシステム

スコアは high_risk, medium_risk, low_risk の件数を用いて
`10 - high*HIGH_WEIGHT - medium*MEDIUM_WEIGHT - low*LOW_WEIGHT` で計算されます。
各定数のデフォルト値は `security_score.py` で次のように定義されています。

```python
HIGH_WEIGHT = 4.5
MEDIUM_WEIGHT = 1.7
LOW_WEIGHT = 0.5
UTM_BONUS = 2.0
```
数値が小さいほどリスクが高く、0 から 10 の範囲に丸められます。utm_active が true の場合は計算後に 2.0 のボーナスを加算してから丸めます。

例として Python から直接呼び出す場合は次の通りです。

```python
from security_score import calc_security_score

result = calc_security_score({
    "danger_ports": ["3389"],
    "geoip": "RU",
    "ssl": "invalid",
    "utm_active": true,
    "open_port_count": 3,
})
print(result["score"], result["high_risk"])
```

コマンドラインから UTM スイッチを有効にするには次のように実行します:
```bash
python nwcd_cli.py security-report 192.168.1.10 80,443 valid true JP true
```

## HTML レポート生成


`generate_html_report.py` を使うと、デバイス情報から HTML 形式のレポートを作成できます。
`--pdf` オプションを指定すると、`pdfkit` または `weasyprint` が利用可能な環境では PDF も生成します。
`--csv` を指定すると同時に CSV 形式のレポートも出力します。
PDF 出力には `wkhtmltopdf` (pdfkit) もしくは `weasyprint` をインストールしておく必要があります。

実行例:

```bash
python generate_html_report.py devices.json -o report.html --pdf --csv report.csv
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

`system_utils.py firewall-status` を実行すると、Windows Defender のリアルタイム
保護状態とファイアウォールの有効/無効を確認できます。

```bash
python system_utils.py firewall-status
```

出力例:

```json
{"defender_enabled": true, "firewall_enabled": true}
```

Windows 以外の環境では `defender_enabled` が `null` となります。

## ネットワーク速度測定

`system_utils.py network-speed` は `speedtest-cli` を利用してダウンロード速度、
アップロード速度、および ping を計測します。
LAN スキャン時に計測され、結果は画面にも表示されます。

```bash
python system_utils.py network-speed
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

GeoIP データベースを指定する場合は `--geoip-db` オプションを利用してください。例
として、データベースをリポジトリ外に保存した場合は次のように実行できます。

```bash
python external_ip_report.py --geoip-db /path/to/GeoLite2-Country.mmdb
```

## LANセキュリティ診断

`nwcd_cli.py lan-check` を実行すると、ARPスプーフィングやUPnP有効機器の有無、
複数DHCPサーバなど LAN 内のリスクを確認できます。ローカルサブネットは自動検出
されますが、引数で `192.168.0.0/24` など任意の範囲を指定することもできます。結果
は JSON 形式で出力され、UTMで防御可能な項目も一覧化されます。さらに、外部通信
先の国別件数が `country_counts` フィールドに含まれます。

```bash
python nwcd_cli.py lan-check  # 自動検出されたサブネットを使用
python nwcd_cli.py lan-check 10.0.0.0/24  # サブネットを指定する場合
```

## Network Topology

`generate_topology.py` を使うと `nwcd_cli.py discover-hosts` や `nwcd_cli.py lan-scan` の JSON 出力からネットワーク図を生成できます。
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
ファイルと同じディレクトリに配置してください。`flutter build windows` で作成した
バンドルにこれらを含めないと、アプリから外部スクリプトを呼び出せなくなります。
主なスクリプトは次の通りです。

- `nwcd_cli.py`
- `system_utils.py`
- `generate_html_report.py` (CSV 出力も可能)
- `generate_topology.py`

### 配布手順例

1. `flutter build windows` を実行します。
2. 生成されたバンドルのディレクトリに、リポジトリ直下の `*.py` ファイルをすべて
   コピーします。

   ```bash
   # Windows の例
   cp *.py build/windows/runner/Release/

   # Linux の例
   cp *.py build/linux/x64/release/bundle/
   ```

3. 配布先の PC には Python 3.10 以上と `requirements.txt` 記載のライブラリを
   インストールしてください。

## 貢献

詳しい貢献方法は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
