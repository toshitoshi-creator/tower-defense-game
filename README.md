# Pixel Tower Defense（縦型ドット絵タワーディフェンス）

Godot 4.3 / GDScript。スマートフォン縦画面（基準 390×844）向け。

## 現在の状態：フェーズ4まで完了

| 実装済み | 内容 |
| --- | --- |
| 戦場 | 上部HUD（時間・コイン・撃破数・一時停止）、中央の戦場、下部パネル（陣地耐久力・召喚ボタン）。画面サイズとセーフエリアに合わせて自動レイアウト |
| 敵 | 画面上部から出現して下へ進軍。時間経過で出現間隔短縮（3秒→下限1秒）・同時出現数増加（上限2）・ステータス上昇（毎分+15%）。1:30以降は強敵（オーク戦士）が混ざる（最大25%） |
| ボス | 1・2・3・4分に中ボス（オーガ、回を追うごとにHP/攻撃 ×1.0/1.3/1.6/1.9）、5分に最終ボス（魔王、周囲の味方をまとめて攻撃）。出現時に大きな告知、上部にボスHPバー、ボス不在時は「中ボスまで 0:23」のカウントダウン。通常敵の出現処理・敵数上限とは独立して必ず出現し、時刻を飛び越えても全員出現する |
| 勝利 | 最終ボス撃破で勝利（5分経過だけでは勝利しない） |
| 味方 | 兵士・弓兵・盾兵。下から上へ進軍し、射程内に敵がいなければ「最も陣地に近い敵」を追う（すり抜け対策） |
| 戦闘 | 索敵・接近・近接攻撃・弓兵の矢（Projectile）・防御力計算・HPバー・ダメージ数値・死亡演出 |
| 召喚 | ボタンをタップで召喚。ユニットごとに待ち時間（初期5秒、下限1秒）、コスト×召喚数を全額払えるときだけ実行。拒否時は理由を表示（コイン不足／召喚待ち／上限／戦闘終了） |
| コイン | 初期100。撃破報酬（雑魚5）を撃破時に1回だけ付与し「+5」を表示。補助として毎秒3コインの自然増加（`CoinWallet.passive_income_per_second`、0で無効） |
| 強化 | 下部の「強化 ▲」で強化パネルを開閉（戦闘は止まらない）。召喚速度・召喚数・攻撃力・最大HP・陣地耐久・コイン獲得の6種。各ボタンに現在Lv・次の効果・必要コイン。購入時に効果をトースト表示、攻撃/HP強化は生存中の味方に「UP」表示 |
| 陣地・敗北 | 耐久力1000、0で敗北。結果画面に戦闘時間・撃破数・獲得コイン・中ボス撃破数・最終ボス撃破の有無・リトライ |
| 中断 | バックグラウンド移行／フォーカス喪失で一時停止、「再開」で復帰 |

未実装（後続フェーズ）：タイトル画面・演出・本番ドット絵（フェーズ5）、エクスポート設定。

### ユニット（`resources/units/*.tres`）

| | コスト | HP | 攻撃 | 防御 | 攻撃間隔 | 移動速度 | 射程 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 兵士 | 20 | 100 | 15 | 0 | 1.0秒 | 42 | 近接 |
| 弓兵 | 30 | 55 | 20 | 0 | 1.3秒 | 34 | 120px（矢） |
| 盾兵 | 25 | 220 | 6 | 3 | 1.2秒 | 30 | 近接 |

### 敵（`resources/enemies/*.tres`）とボス出現表（`resources/bosses/*.tres`）

| | HP | 攻撃 | 防御 | 報酬 | 備考 |
| --- | --- | --- | --- | --- | --- |
| ゴブリン（雑魚） | 60 | 8 | 0 | 5 | 時間でHP/攻撃が増える |
| オーク戦士（強敵） | 180 | 14 | 2 | 12 | 1:30から混ざる |
| オーガ（中ボス） | 900 | 30 | 3 | 100 | 出現ごとに倍率（BossSpawn.stat_multiplier） |
| 魔王（最終ボス） | 2200 | 30 | 5 | 300 | 範囲攻撃（abilities: cleave） |

バランスの目安（ヘッドレスでのボット6戦ずつ）：召喚し強化も買うボットは6戦4勝、召喚だけのボットは6戦全敗、何もしないと約45秒で敗北。

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

## 起動方法

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/)（標準版、.NET不要）をインストール
2. Godot のプロジェクトマネージャーで「インポート」→ このフォルダの `project.godot` を選択
3. F5（プロジェクトを実行）。メインシーンは `scenes/battle/battle.tscn`。起動するとすぐ戦闘が始まります

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
4. メインシーンをゲーム内3分間ヘッドレス実行し、エラー・警告が出ないことを確認

画面確認用のスクリーンショット取得（描画環境が必要）：

```sh
godot --path . -s res://tools/capture_screenshot.gd -- <秒数> <出力.png> [時間倍率] [bot]
```

## 構成

```
scenes/battle/battle.tscn      メインシーン（BattleManager）
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
  pixel_art.gd                 仮ドット絵パターン（ユニットとUIアイコンで共用）
scripts/data/unit_data.gd      ユニット定義 Resource
scripts/data/upgrade_data.gd   強化定義 Resource（resources/upgrades/）
resources/units/              兵士・弓兵・盾兵
resources/enemies/grunt.tres   雑魚敵（ゴブリン）
resources/ui_theme.tres        UIテーマ
assets/fonts/                  DotGothic16（SIL OFL 1.1、OFL.txt 同梱）
```

新しいユニットは `UnitData` の `.tres` を追加するだけで、戦闘処理の変更は不要です。

## 仮素材と差し替え

キャラクターは `pixel_art.gd` の 12px 幅ドットパターンを 3 倍で描画した仮素材です。
`UnitData.sprite_frames` に `SpriteFrames` を設定すると、自動的にそちらが使われます。

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
