# Pixel Tower Defense（縦型ドット絵タワーディフェンス）

Godot 4.3 / GDScript。スマートフォン縦画面（基準 390×844）向け。

## 現在の状態：フェーズ1

| 実装済み | 内容 |
| --- | --- |
| 戦場 | 上部HUD・中央の戦場・下部パネル。画面サイズとセーフエリアに合わせて自動レイアウト |
| 敵 | 画面上部から出現して下へ進軍。時間経過で出現間隔短縮・同時出現数増加・ステータス上昇 |
| 味方 | 陣地の前から出現して上へ進軍（**フェーズ1の仮処理として自動出撃**。召喚ボタンとコインはフェーズ2） |
| 戦闘 | 索敵 → 接近 → 近接攻撃、攻撃間隔、防御力計算、HPバー、ダメージ数値、死亡演出 |
| 陣地 | 耐久力1000。敵が到達すると攻撃を受け、HUDバー減少・赤フラッシュ |
| 勝敗 | 耐久力0で敗北 → 結果画面（戦闘時間・撃破数・ボス撃破数・リトライ）。勝利判定の受け口（`notify_final_boss_defeated()`）は実装済みで、最終ボスはフェーズ4 |
| 中断 | アプリのバックグラウンド移行／フォーカス喪失で一時停止。「再開」ボタンで復帰。上部の「II」でも一時停止 |

未実装（後続フェーズ）：コイン、召喚ボタン、弓兵・盾兵・飛び道具、強化、ボス、タイトル画面、本番ドット絵、エクスポート設定。

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
3. `tests/run_tests.gd`（ヘッドレス、`--fixed-fps 60`）の結合テスト
4. メインシーンをゲーム内3分間ヘッドレス実行し、エラー・警告が出ないことを確認

画面確認用のスクリーンショット取得（描画環境が必要）：

```sh
godot --path . -s res://tools/capture_screenshot.gd -- <秒数> <出力.png> [時間倍率]
```

## 構成

```
scenes/battle/battle.tscn      メインシーン（BattleManager）
scenes/units/                  ally_unit.tscn / enemy_unit.tscn
scenes/ui/                     battle_ui.tscn / result_ui.tscn
scripts/battle/
  battle_manager.gd            戦闘全体・勝敗判定（同一フレームで勝敗が重なったら勝利優先、結果表示は1回のみ）
  battle_clock.gd              戦闘時間（単調増加、終了後停止）
  battle_layout.gd             戦場の座標（画面サイズ変更時に更新）
  enemy_spawner.gd             敵の出現と難易度上昇（パラメータは @export）
  summon_manager.gd            味方の生成（フェーズ1は自動出撃）
  base_controller.gd           陣地の耐久力
  battlefield_background.gd    背景描画
scripts/units/
  combatant.gd                 味方・敵共通の戦闘処理（索敵・移動・攻撃・ダメージ・死亡）
  unit_base.gd / enemy_base.gd 味方／敵の差分のみ
  combatant_visual.gd          見た目（SpriteFrames があれば使用、なければドット絵の仮描画）
scripts/data/unit_data.gd      ユニット定義 Resource
resources/units/soldier.tres   兵士
resources/enemies/grunt.tres   雑魚敵（ゴブリン）
resources/ui_theme.tres        UIテーマ
assets/fonts/                  DotGothic16（SIL OFL 1.1、OFL.txt 同梱）
```

新しいユニットは `UnitData` の `.tres` を追加するだけで、戦闘処理の変更は不要です。

## 仮素材と差し替え

キャラクターは `combatant_visual.gd` の 12px 幅ドットパターンを 3 倍で描画した仮素材です。
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
