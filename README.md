# Pixel Tower Defense（縦型ドット絵タワーディフェンス）

Godot 4.3 / GDScript。スマートフォン縦画面（基準 390×844）向け。

## 現在の状態：2ステージ＋成長要素

| 機能 | 内容 |
| --- | --- |
| ホーム | 起動するとホーム画面。ランク・EXP・コイン・オーブを表示。ステージ選択／編成／強化／ガチャ／ショップへ |
| ステージ選択 | ステージ1 草原の砦、ステージ2 荒野の関所（ステージ1クリアで解放）。各ステージは `resources/stages/*.tres` |
| 戦闘 | 5分間の防衛戦（召喚・コイン・戦闘中の強化・中ボス4体・最終ボス）。味方は兵種ごとの役割で動く |
| クリア報酬 | 勝利時にルーレットでコイン（またはまれにオーブ）が決まり、ランクEXPも入る。報酬は勝利の瞬間に確定・保存し、ルーレットはその結果を表示する（回さずに戻っても失われず、リロードでの引き直しもできない） |
| ランク | クリアでランクEXP。ランクアップごとにコインとオーブ |
| 強化（永続） | 戦闘中の6つの強化項目をコインでレベルアップ。戦闘はそのレベルから始まる（上限は戦闘中上限の半分） |
| ガチャ | オーブでキャラクターを入手。同じキャラが出るとレベルアップ（Lv10まで、以降はコイン）。提供割合を画面に表示 |
| 編成 | 出撃する3体を選ぶ。キャラのレベルは HP・攻撃に反映（1レベルごと+8%） |
| ショップ | オーブの購入。**現在はテストモード（請求なし）**。ストア決済は未接続 |
| セーブ | `user://save.json`（ブラウザ版はそのブラウザ内に保存）。壊れたデータは初期状態から再開 |

コインは戦闘中と同じ「G」。戦闘中に稼いだコインは従来どおりその戦闘だけで使い切り、持ち越すのはクリア時のルーレットとランクアップの報酬。

### 進行の表（`scripts/meta/game_catalog.gd` に集約）

| 項目 | 値 |
| --- | --- |
| ルーレット | 100G 30% / 200G 25% / 300G 20% / 500G 12% / 1000G 6% / オーブ30 7%（ステージ2はコイン×1.5） |
| ランクEXP | 次のランクまで 100 + 50×(ランク−1)。ステージ1クリア 120、ステージ2クリア 200 |
| ランクアップ報酬 | コイン 200 + 50×新ランク、オーブ 50 |
| 永続強化の価格 | 戦闘中の基本コスト × 5 × 1.6^レベル |
| ガチャ | 1回 50オーブ、10回 450オーブ。N 60%（兵士・弓兵・盾兵）／R 30%（槍兵・重装兵・騎士）／SR 10%（魔法使い・ヒーラー） |
| オーブ | 購入分（有償）と報酬分（無償）を分けて記録し、無償分から先に使う |

### ユニット（`resources/units/*.tres`）

| | 役割 | コスト | HP | 攻撃 | 防御 | 攻撃間隔 | 特徴 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 兵士 | 突撃 | 20 | 100 | 15 | 0 | 1.0秒 | 標準 |
| 弓兵 | 支援 | 30 | 55 | 20 | 0 | 1.3秒 | 矢（射程120） |
| 盾兵 | 守備 | 25 | 220 | 6 | 3 | 1.2秒 | 防衛線 |
| 槍兵 | 突撃 | 30 | 110 | 18 | 0 | 1.2秒 | 長いリーチ |
| 騎士 | 突撃 | 45 | 210 | 22 | 2 | 1.0秒 | 速くて硬い |
| 重装兵 | 守備 | 40 | 420 | 8 | 6 | 1.4秒 | とても硬い |
| 魔法使い | 支援 | 45 | 50 | 24 | 0 | 1.8秒 | 着弾点の周りにも当たる |
| ヒーラー | 支援 | 40 | 60 | 18 | 0 | 1.5秒 | 味方を回復、攻撃しない |

### 敵（`resources/enemies/*.tres`）とボス出現表（`resources/bosses/*.tres`）

| | HP | 攻撃 | 防御 | 報酬 | 備考 |
| --- | --- | --- | --- | --- | --- |
| ゴブリン（雑魚） | 60 | 8 | 0 | 5 | 時間でHP/攻撃が増える |
| オーク戦士（強敵） | 180 | 14 | 2 | 12 | 1:30から混ざる |
| オーガ（中ボス） | 900 | 30 | 3 | 100 | 出現ごとに倍率（BossSpawn.stat_multiplier） |
| 魔王（最終ボス） | 2200 | 30 | 5 | 300 | 範囲攻撃（abilities: cleave） |

バランスの目安（ヘッドレスでのボット6戦ずつ、兵士5:弓兵3:盾兵2で召喚）：強化も買うボットは6戦4勝、召喚だけのボットは6戦全敗、何もしないと約45秒で敗北。

### 強化（`resources/upgrades/*.tres`）

次のレベルの費用 = round(基本コスト × 1.5^現在レベル)（`BattleUpgradeManager.cost_for_level` に集約）。

| 強化 | 基本コスト | 上限Lv | 1Lvあたり | 備考 |
| --- | --- | --- | --- | --- |
| 召喚速度 | 50 | 5 | 間隔 −15% | 5秒→Lv5で1.25秒（下限1秒） |
| 召喚数 | 100 | 3 | +1体 | 次回の召喚から。費用は単価×体数 |
| 攻撃力 | 40 | 10 | +15% | 生存中の味方にも即時反映 |
| 最大HP | 40 | 10 | +15% | 生存中の味方は最大HPの増加分だけ現在HPも増える（全回復はしない） |
| 陣地耐久 | 60 | 5 | +200 | 最大値と現在値の両方が+200 |
| コイン獲得 | 80 | 5 | 撃破報酬 +20% | 自然増加分には掛からない |

強化レベル・コイン・味方は戦闘ごとにシーンごと作り直されるため、リトライや次の戦闘では必ず初期状態に戻ります。

## ブラウザ版

`tools/build_web.sh` で `build/artifact/` にブラウザ版を作ります（Godot 4.3 の Web 用エクスポートテンプレートが必要）。
スレッドなし版なので特別なサーバー設定は不要です。claude.ai の Artifact として公開するため、
35MB のエンジンを3つの `.wasm` に分割し、ゲームデータ（.pck）を base64 の JS に埋め込み、
`web/pixel-defense.html` が読み込み時に組み立てます。

## 課金（オーブ購入）について

- ショップは `PurchaseService` を通して購入します。現在は**テストモードのみ**で、購入ボタンを押すと請求なしでオーブが付与されます（画面にも表示）。
- 実際に販売するには、Android は Google Play Billing、iOS は StoreKit のプラグインを組み込み、`PurchaseService._buy_with_store()` を実装します。付与は取引IDごとに1回だけ（`PlayerData.grant_purchase`）。
- 日本で有償通貨・ガチャを提供する場合、資金決済法（前払式支払手段）や景品表示法、業界のガイドライン（確率表示など）への対応が必要です。リリース前に専門家の確認をおすすめします。

## スマートフォン向け書き出し

`export_presets.cfg` に Android / iOS のプリセットを用意しています（縦画面固定、パッケージID `com.example.pixeltowerdefense`、ネット権限なし）。

- **設定ファイルを用意しただけで、APK / IPA の書き出しと実機での動作確認はまだ行っていません。**
- この環境で `--export-debug` を実行すると、Godot はプリセットを読み込んだうえで「エクスポートテンプレートがない」「Android SDK のパスが未設定」で停止します。
- 書き出すには Godot エディタでエクスポートテンプレート（4.3）を導入し、Android は SDK とキーストア、iOS は macOS + Xcode と Apple Developer の Team ID を設定してください。
- パッケージID・アプリ名は公開前に変更してください。

## 起動方法

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/)（標準版、.NET不要）をインストール
2. Godot のプロジェクトマネージャーで「インポート」→ このフォルダの `project.godot` を選択
3. F5（プロジェクトを実行）。タイトル画面の「スタート」で戦闘開始（メインシーンは `scenes/title/title.tscn`、戦闘は `scenes/battle/battle.tscn`）

コマンドラインの場合：

```sh
godot --path .            # ゲームを起動
```

## テスト

```sh
GODOT=/path/to/godot tests/run_all.sh
```

1. リソースのインポート（エラー・警告なし）
2. 全 GDScript を「既定の警告をすべてエラー扱い」にして構文チェック
3. `tests/run_tests.gd`（ヘッドレス、`--fixed-fps 60`、画面390×844）の結合テスト。
   召喚し続けるボットと何もしないプレイヤーの比較など、ゲーム内数分間のシミュレーションを含む
4. タイトル画面と、戦闘シーン（ゲーム内3分間）をヘッドレス実行し、エラー・警告が出ないことを確認

画面確認用のスクリーンショット取得（描画環境が必要）：

```sh
godot --path . -s res://tools/capture_screenshot.gd -- <秒数> <出力.png> [時間倍率] [bot]
```

## 構成

```
scenes/title/title.tscn        タイトル（起動シーン）
scenes/battle/battle.tscn      戦闘（BattleManager）
scenes/units/                  ally_unit.tscn / enemy_unit.tscn
scenes/ui/                     battle_ui.tscn / result_ui.tscn / summon_button.tscn / upgrade_button.tscn
scenes/battle/projectile.tscn  矢
scripts/battle/
  battle_manager.gd            戦闘全体・勝敗判定（同一フレームで勝敗が重なったら勝利優先、結果表示は1回のみ）
  battle_clock.gd              戦闘時間（単調増加、終了後停止）
  battle_layout.gd             戦場の座標（画面サイズ変更時に更新）
  enemy_spawner.gd             敵の出現と難易度上昇（パラメータは @export）
  summon_manager.gd            召喚（待ち時間・コスト・召喚数・上限・拒否理由）
  coin_wallet.gd               戦闘中のみのコイン
  battle_upgrade_manager.gd    戦闘中の強化（レベル・費用計算・効果適用）
  projectile.gd                矢
scripts/data/boss_spawn.gd     ボス出現1件（時刻・ユニット・倍率・最終ボスか・告知文）
  base_controller.gd           陣地の耐久力
  battlefield_background.gd    背景描画
scripts/units/
  combatant.gd                 味方・敵共通の戦闘処理（索敵・移動・攻撃・ダメージ・死亡）
  unit_base.gd / enemy_base.gd 味方／敵の差分のみ
  combatant_visual.gd          見た目（SpriteFrames があれば使用、なければドット絵の仮描画）
  pixel_art.gd                 仮ドット絵パターンとアニメーション生成（ユニットとUIアイコンで共用）
scripts/effects/               ダメージ数値・コイン表示（floating_text）、火花・破片（pixel_burst）
scripts/title/                 ホーム画面
scripts/meta/                  セーブデータ（player_data）、進行の表（game_catalog）、各メニュー画面、購入（purchase_service）
scenes/meta/                   ステージ選択・編成・強化・ガチャ・ショップ
resources/stages/              ステージ定義
scripts/data/unit_data.gd      ユニット定義 Resource
scripts/data/upgrade_data.gd   強化定義 Resource（resources/upgrades/）
resources/units/              兵士・弓兵・盾兵
resources/enemies/grunt.tres   雑魚敵（ゴブリン）
resources/ui_theme.tres        UIテーマ
assets/fonts/                  DotGothic16（SIL OFL 1.1、OFL.txt 同梱）
```

新しいユニットは `UnitData` の `.tres` を追加するだけで、戦闘処理の変更は不要です。

## 仮素材と差し替え

キャラクターは `pixel_art.gd` の 12px 幅ドットパターンから起動時にテクスチャを生成し、
`SpriteFrames`（idle 2枚・move 2枚・attack 2枚・hurt 1枚・death 3枚）として再生しています。
同じ見た目のユニットはテクスチャを共有し、1体につき1スプライトで描画します。
`UnitData.sprite_frames` に本番の `SpriteFrames` を設定すると、自動的にそちらが使われます（その場合は等倍表示）。

本番素材の推奨仕様（Nearest フィルタ、整数倍表示前提）：

| 素材 | 推奨サイズ（1フレーム） | アニメーション |
| --- | --- | --- |
| 兵士 / 弓兵 / 盾兵 | 16×16 | idle(2) move(4) attack(3) hurt(1) death(4) |
| 雑魚敵 / 強敵 | 16×16 | idle(2) move(4) attack(3) hurt(1) death(4) |
| 中ボス | 32×32 | idle(2) move(4) attack(4) hurt(1) death(6) |
| 最終ボス | 48×48 | idle(4) move(4) attack(6) hurt(1) death(8) |
| 矢 | 8×3 | 1枚 |
| 陣地 | 幅いっぱいのタイル 16×16 ×数種 | 通常 / 損傷 |

アニメーション名は `idle` / `move` / `attack` / `hurt` / `death` で統一してください。
