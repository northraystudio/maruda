# maruda

**AI with a harness.** — AI開発に、ハーネスをまるっと。

maruda（まるだ）は、「まるっと」と **DA**（Dev with AI）から付けた名前です。
スキルだけでなく、ルール、CI、セキュリティのゲート、フックを一式で配ります。

English: [README.md](README.md)

maruda は、Claude Code のエージェントスキル群と、AI 支援開発のための**プロジェクト
ハーネス**です。コード品質のレビュー、セキュリティ監査、コードから生成する仕様書、
GitHub Issue 起点の実装と自律検証、初日から効く CI とセキュリティゲート
（gitleaks / Semgrep / Trivy）を含みます。**ハーネスエンジニアリング**と
**ループエンジニアリング**の考え方に基づき、環境が機械的に品質を強制し
（フック、厳格な CI、ブランチ保護）、境界のある改善ループ
（診断 → Issue → 計画 → 実装 ⇄ 検証）が仕事をします。

> **`dev-skills` から改名しました。** このリポジトリは 2026-09-20 に
> `ymd38/dev-skills` から `northraystudio/maruda` へ移管・改名しました。旧 URL は
> GitHub が転送するので、旧アドレスを指したままのワンライナーやクローンは動き続け、
> 導入済みのプロジェクトで必要な作業はありません。新しいリンクには新アドレスを
> 使ってください。

## スキルとは

スキルは、特定の作業に必要な知識・手順・出力テンプレートをエージェントに与える
Markdown ファイルです。導入すると、Claude Code が関連する依頼を認識して自動的に
適用します。毎回プロンプトで指示する必要はありません。

## 継続的改善サイクル

```
診断（software-evaluation / vulnerability-scan / data-validation）
  → 可視化（progress-dashboard）
  → Issue 登録（report-to-issues）／ Issue 起票（gh-issue-drafter）
  → 計画（gh-issue-planner）
  → 実装 ⇄ 検証（gh-issue-resolver、複数まとめるなら gh-batch-runner）
```

- 診断系のスキルは**読み取り専用**です。証拠を出すだけで、コードやデータを黙って
  書き換えません。
- 実装には、`gh-issue-planner` が Issue に投稿した**合意プランのコメント**が要ります。
- `gh-issue-resolver` が自律的に直せるのは、**自分の変更が壊したもの**だけです
  （リグレッション、3回まで）。元から壊れていたものは `report-to-issues` に渡します。

## スキル一覧

| スキル | 説明 |
| --- | --- |
| [spec-doc](skills/spec-doc/SKILL.md) | コードから「生きた仕様書」を生成・同期し、ドキュメントと実装の乖離をなくす |
| [software-evaluation](skills/software-evaluation/SKILL.md) | 5つの柱（アーキテクチャ / 信頼性 / 可観測性 / セキュリティ / DX）でコード品質を評価し、1〜10 のスコアカードと改善ロードマップを出す |
| [vulnerability-scan](skills/vulnerability-scan/SKILL.md) | Semgrep を使った OWASP ベースの攻撃的セキュリティ監査。深刻度と修正方針付きの読み取り専用レポート |
| [data-validation](skills/data-validation/SKILL.md) | プロジェクト自身のフィクスチャ、または明示的に設定した非本番接続からデータを読み、件数・NULL 率・分布・一意性・参照整合性・書式を検証する。読み取り専用、JSON は出さない |
| [report-to-issues](skills/report-to-issues/SKILL.md) | 評価・監査レポートを読み、対話的に選んだ項目を `gh` CLI で GitHub Issue に登録する |
| [gh-issue-drafter](skills/gh-issue-drafter/SKILL.md) | ざっくりした要望を、完了条件・触らない範囲・設計方針まで揃った Issue に仕立てる |
| [gh-issue-planner](skills/gh-issue-planner/SKILL.md) | Issue を取得してコードを調査し、対応方針・影響範囲・実装手順を合意プランとしてコメントする。実装はしない |
| [gh-issue-resolver](skills/gh-issue-resolver/SKILL.md) | 合意プランのある Issue を実装し、テストと診断を再実行して、自分の変更が壊した分だけを自律的に直し、PR を出す |
| [gh-batch-runner](skills/gh-batch-runner/SKILL.md) | 複数の Issue を1リリースとしてまとめる。Epic Issue がメンバーを持ち、共有の `epic/**` ブランチに Issue ごと1コミットで積み、全体を検証して PR は1本 |
| [progress-dashboard](skills/progress-dashboard/SKILL.md) | JSON 要約から、品質スコアとセキュリティ指摘の推移を見る HTML ダッシュボードを生成する |
| [setup](skills/setup/SKILL.md) | 短いインタビューでハーネス一式（CLAUDE.md、フック、settings、ルール）を導入する。言語やコマンドは必ず質問し、自動検出しない |

## 導入

### 使い方別の早見表

| 状況 | やること |
| --- | --- |
| **Claude Code を使っていて、スキルだけ欲しい** | `/plugin marketplace add northraystudio/maruda` → `/plugin install maruda@northraystudio`。コマンドは `/maruda:<skill>` の形で入る |
| **Claude Code 以外のエージェント、または plugin を使わない** | `npx skills add northraystudio/maruda --skill '*' --agent claude-code -y --copy` |
| **新規プロジェクト、言語が決まっている** | 下のフルのワンライナーに `--langs` を渡す。`git init` → 初回 push → `--protect` |
| **新規プロジェクト、言語が未定** | 下の最小のワンライナー（レールだけ）→ あとで `/maruda:setup` |
| **既存プロジェクト** | フルのワンライナー。既存の `CLAUDE.md` / settings / フックは上書きされず、settings のフックはマージされる。その後 `/maruda:setup` |
| **チームで共有したい** | `--copy` で入れて `.claude/`、`CLAUDE.md`、`.github/` をコミットする。または `setup.sh --plugin` で plugin をリポジトリに記録する |
| **フラグより質問に答えたい** | 先にスキルを入れて、Claude Code で `/maruda:setup` |
| **ゲートを実際に効かせたい** | ワンライナーに `--protect` を足す（`gh` の admin 権限が必要） |
| **AI の PR レビューを足したい** | ワンライナーに `--pr-agent`、そのあと `OPENAI_KEY` をリポジトリシークレットに登録する。助言のみで、必須チェックにはしない |
| **最新に更新したい** | 同じ導入コマンドを再実行する。差分のあるファイルは `<file>.new` として提案され、上書きはされない |

```bash
# フル（言語は必ず明示。自動検出しない）
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh \
  | bash -s -- --langs go,typescript --pm pnpm --with-skills

# 最小（レールだけ）
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh \
  | bash -s -- --minimal
```

### plugin として入れる（Claude Code、推奨）

```
/plugin marketplace add northraystudio/maruda
/plugin install maruda@northraystudio
```

スキルは名前空間付きで入ります（`/maruda:spec-doc`、`/maruda:setup`、
`/maruda:gh-issue-planner`）。他のスキル集と衝突せず、同梱の
`harness/scripts/setup.sh` は常にスキルと同じ版です。

plugin を入れたあとに実行するのは `/maruda:setup` の1つだけです。plugin は
プロジェクトにファイルを書けないので、`CLAUDE.md`、`.claude/hooks/`、
`.claude/settings.json`、`.claude/rules/`、CI は引き続き `setup.sh` の担当です。

`main` を追うのではなくリリースを固定したい場合は、marketplace に ref を付けます。

```json
// .claude/settings.json
{
  "extraKnownMarketplaces": {
    "northraystudio": {
      "source": { "source": "github", "repo": "northraystudio/maruda", "ref": "v0.1.0" }
    }
  },
  "enabledPlugins": { "maruda@northraystudio": true }
}
```

この2つのキーは `setup.sh --plugin`（タグを固定するなら `--plugin-ref v0.1.0`）が
既存の内容を壊さずにマージして書きます。ただし **Claude Code は settings からの
自動インストールはしません**。これらのキーは marketplace を登録して plugin を有効に
するだけなので、各自が一度 `/plugin install maruda@northraystudio` を実行します。

### ハーネス一式を入れる

スキルだけでは作業手順（L1）にとどまります。ハーネスは機械的なガードレールを
足します（L2〜L3）：書き込み時のフォーマット、危険なコマンドのガード、簡潔な
`CLAUDE.md`、サイクルのルール、GitHub Actions の CI、セキュリティスキャン。

| 入口 | 使いどころ |
| --- | --- |
| `curl \| bash` のワンライナー | まっさらな環境 / CI / とにかく入れたいとき（非対話、フラグ必須） |
| `harness/scripts/setup.sh` | すでにこのリポジトリをクローンしているとき |
| Claude Code の `/maruda:setup` | 言語やコマンドを対話で決めたいとき（自動検出しない） |
| `--plugin` | クローンした全員が同じスキルを入れられるよう、plugin を `.claude/settings.json` に記録する |

```bash
# クローンから
./harness/scripts/setup.sh --target /path/to/your-project --langs python --python-pm uv
```

パイプする前に中身を見たい場合：

```bash
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh -o install.sh
less install.sh && bash install.sh --langs go
```

**既存ファイルは上書きされません。** 入ってくるファイルが手元と違うときは、
`<file>.new` として隣に置かれます（pacman の `.pacnew` 方式）。`diff` で確認し、
必要な分をマージしてから `.new` を消してください。内容が同じなら古い `.new` は
消えます。`--force` を付けたときだけ上書きします。`settings.json` だけは例外で、
フックは自動でマージされます（既存のエントリは保持）。最後のチェックリストに、
提案されたファイルが一覧で出ます。

対応言語は Go / Python / TypeScript / JavaScript。すべてのフラグは
`setup.sh --help` を見てください。

> **`yds-` 付きの名前からの移行：** `yds-` 接頭辞は廃止しました。フラットな
> コマンド一覧でスキルをまとめるための接頭辞でしたが、その役目は plugin の
> 名前空間が担います。`/yds-spec-doc` は plugin では `/maruda:spec-doc`、
> `npx skills add` では `/spec-doc` になります。改名前に導入したプロジェクトでは
> **`.claude/skills/yds-*` を削除**してから入れ直してください。残すと同じスキルが
> 二重に登録されます。サイクルのルールも
> `.claude/rules/dev-skills-cycle.md` から `.claude/rules/maruda-cycle.md` に
> 変わりました。`setup.sh` は自分が書いていないファイルを消さないので、古い方は
> 報告するだけです。submodule の置き場所も `.claude/maruda` になりました
> （使っている場合は `git mv .claude/dev-skills .claude/maruda`）。
> 引き継ぎマーカー（`<!-- gh-issue-planner:agreed-plan -->` など）と JSON 要約の
> `type` の値は旧名のままなので、既存の Issue とダッシュボードのデータは
> そのまま使えます。

### スキルだけ入れる

```bash
# すべてのスキルを非対話で .claude/skills/ にコピー
npx skills add northraystudio/maruda --skill '*' --agent claude-code -y --copy

# 1つだけ
npx skills add northraystudio/maruda --skill spec-doc --agent claude-code -y --copy
```

submodule で入れる場合：

```bash
git submodule add https://github.com/northraystudio/maruda.git .claude/maruda
```

## 使い方

```
/maruda:spec-doc src/
/maruda:software-evaluation src/backend/
/maruda:vulnerability-scan src/
/maruda:data-validation db/
/maruda:report-to-issues docs/evaluation/myapp.20260406.md
/maruda:gh-issue-drafter
/maruda:gh-issue-planner
/maruda:gh-issue-resolver
/maruda:gh-batch-runner
/maruda:progress-dashboard
/maruda:setup
```

`npx skills add` で入れた場合は、名前空間なしで `/spec-doc` のようになります。

## 決定の記録

設計上の判断は `docs/adr/` に ADR として残しています。スキル名から接頭辞を外した
理由（0003）、フックを plugin に移さない理由（0004）、リポジトリのルートを plugin
兼 marketplace にした理由とバージョン固定の方法（0005）など。

## ライセンス

MIT — [LICENSE](LICENSE) を参照してください。
