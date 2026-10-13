# maruda の導入 — 詳細

短い版は [README.ja.md](../README.ja.md#導入) にあります。このページには、
インストーラが生成するもの、入口とフラグ、更新の仕方、旧 `yds-` 名からの移行を
まとめています。フラグの完全な一覧は英語版の
[docs/install.md#flags](install.md#flags) と `setup.sh --help` を参照してください。

- [入口](#入口)
- [ハーネス一式が生成するもの](#ハーネス一式が生成するもの)
- [既存ファイルは上書きされない](#既存ファイルは上書きされない)
- [ゲートの成熟度ラダー](#ゲートの成熟度ラダー)
- [スキルだけ](#スキルだけ)
- [更新](#更新)
- [`yds-` 付きの名前からの移行](#yds--付きの名前からの移行)

## 入口

| 入口 | 使いどころ |
| --- | --- |
| `curl \| bash` のワンライナー | まっさらな環境 / CI / とにかく入れたいとき（非対話、フラグ必須） |
| `harness/scripts/setup.sh` | すでにこのリポジトリをクローンしているとき |
| Claude Code の `/maruda:setup` | 言語やコマンドを対話で決めたいとき（自動検出しない） |
| `--plugin` | クローンした全員が同じスキルを入れられるよう、plugin を `.claude/settings.json` に記録する（`--with-skills` とは排他） |

```bash
# ワンライナー
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh \
  | bash -s -- --langs go,typescript --pm pnpm --with-skills     # フル
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh \
  | bash -s -- --minimal                                         # レールだけ

# クローンから
./harness/scripts/setup.sh --target /path/to/your-project --langs python --python-pm uv
```

パイプする前に中身を見たい場合：

```bash
curl -fsSL https://raw.githubusercontent.com/northraystudio/maruda/main/harness/scripts/install.sh -o install.sh
less install.sh && bash install.sh --langs go
```

対応言語は Go / Python / TypeScript / JavaScript。すべてのフラグは
`setup.sh --help` を見てください。インストーラの回帰テストは
`bash harness/tests/run.sh` です。

## ハーネス一式が生成するもの

スキルだけでは作業手順（L1）にとどまります。ハーネスは機械的なガードレールを
足します（L2〜L3）。L4（スケジュールされた自動診断）は意図的に対象外です。

常に（`--minimal` はこのうち `CLAUDE.md` 以外だけを入れる）：

- `CLAUDE.md` — スタックとコマンド、サイクル、ハードルール（`--minimal` では
  書かない。あとで `/maruda:setup` で埋める）
- `.claude/hooks/` — 書き込み時フォーマット、危険 bash のガード、SessionStart の
  コンテキスト、Stop 時の促し
- `.claude/settings.json` — 既存の内容にフックをマージ
- `.claude/rules/maruda-cycle.md` — サイクルの契約
- `.env.example` と `.gitignore` の `.env` エントリ

`--langs` を付けると（`--minimal` と `--no-ci` では省略）：

- `.github/workflows/ci.yml` — 言語ごとのジョブ（Go: go.mod ガード / tidy
  チェック / build / `test -race` / 版固定の golangci-lint。Node: スクリプトの
  事前確認 / frozen-lockfile インストール / lint / typecheck（TS）/ test。
  Python: ruff / pytest）。**意図的に厳格**で、lint / typecheck / test の
  スクリプトがない、あるいはテストが 0 件ならジョブは失敗し、何を足すべきかを
  `::error` で示します。どちらのワークフローも既定ブランチへの直接 push で動きます
- `.github/workflows/security-scan.yml` — gitleaks と semgrep は初日からゲート、
  trivy は `continue-on-error` で段階導入、Node の本番依存の audit
- `.gitleaks.toml` と `.semgrepignore` — 許可リストは最小単位のみ
- `docs/harness-checklist.md` — 厳格な CI を緑にする手作業（スクリプト追加、
  最初のテスト、lockfile のコミット、ブランチ保護、trivy の昇格）。終わったら削除
- `.claude/rules/` — **採点基準に揃えたコーディング原則**（KISS / YAGNI と、
  `software-evaluation` の 5 つの柱を「最初から正しく書く」ルールに反転したもの。
  各ルールに採点される柱のタグが付き、セキュリティのルールは
  `vulnerability-scan` の指摘を先回りする）と、言語別のベストプラクティス
  （`go.md` / `python.md` / `typescript.md`、`--langs` に応じて）

`--pr-agent` を付けると：

- `.github/workflows/pr-agent.yml` と `.pr_agent.toml` —
  [qodo-ai/pr-agent](https://github.com/qodo-ai/pr-agent) による助言のみの AI
  レビュー（PR を開くと describe / review / improve、push ごとに `/review`、
  リポジトリメンバーはスラッシュコマンド。action はリリースタグの SHA に固定）。
  `OPENAI_KEY` シークレットと API 課金が要るためオプトイン。**必須チェックには
  しない**。CI が既にあるプロジェクト向けに `--no-ci` と組み合わせられる

CI のツールと action の版は固定（`@latest` なし）。ローカルのフォーマットフックは
プロジェクトに入っているフォーマッタだけを動かし、コードをダウンロードしません。

**チェックがマージを止めるのは、ブランチ保護で必須にしたときだけです。**
インストーラはチェックリストで保護の状態を報告します。`--protect`（push 済みの
既定ブランチと `gh` の admin 権限が必要）で必須ステータスチェックを自動適用するか、
GitHub の設定で行ってください。未設定は「成功」ではなく「未完了」として報告されます。

## 既存ファイルは上書きされない

入ってくるファイルが手元と違うときは、`<file>.new` として隣に置かれます
（pacman の `.pacnew` 方式）。`diff <file> <file>.new` で確認し、必要な分を
マージしてから `.new` を消してください。内容が同じなら古い `.new` は消えます。
`--force` を付けたときだけ上書きします。`settings.json` だけは例外で、フックは
自動でマージされます（既存のエントリは保持）。最後のチェックリストに、提案された
ファイルが一覧で出ます。

## ゲートの成熟度ラダー

既定は初日向けの設定です。プロジェクトの成熟に合わせて昇格させます：

| 段階 | いつ | やること |
| --- | --- | --- |
| **0 — 初日**（既定） | 新しいプロジェクト | gitleaks + semgrep は止める。trivy は知らせるだけ（`continue-on-error`）。CI は厳格（スクリプトやテストがなければ失敗） |
| **1 — 依存を精査済み** | Trivy の指摘を確認し、直せないものは理由付きで `.trivyignore` に入れた | `security-scan.yml` の `continue-on-error: true` を消す。trivy がゲートになる |
| **2 — 強制** | 既定ブランチを push 済みで、admin 権限がある | `setup.sh --protect`（または GitHub の設定）。チェックが必須になり、force-push と削除が止まる |
| **3 — 引き締め** | チームのリズムが安定し、誤検知が少ない | `--audit-level` を `moderate` に上げる、より厳しい Semgrep ルールセット（例 `p/cwe-top-25`）を足す、`strict: true` のレビューを検討 |

PR Agent（`--pr-agent`）は意図的にラダーの外です。助言であってゲートではなく、
`--protect` は必須チェックに加えません。

## スキルだけ

### Claude Code plugin（推奨）

```
/plugin marketplace add northraystudio/maruda
/plugin install maruda@northraystudio
```

スキルは名前空間付きで入ります（`/maruda:spec-doc`、`/maruda:setup`、
`/maruda:gh-issue-planner`）。他のスキル集と衝突せず、同梱の
`harness/scripts/setup.sh` は常にスキルと同じ版です。plugin を入れたあとに
実行するのは `/maruda:setup` の 1 つだけです。plugin はプロジェクトにファイルを
書けないので、`CLAUDE.md`、`.claude/hooks/`、`.claude/settings.json`、
`.claude/rules/`、CI は引き続き `setup.sh` の担当です。

`main` を追うのではなくリリースを固定したい場合は、marketplace に ref を付けます。

```json
// .claude/settings.json
{
  "extraKnownMarketplaces": {
    "northraystudio": {
      "source": { "source": "github", "repo": "northraystudio/maruda", "ref": "maruda--v0.2.0" }
    }
  },
  "enabledPlugins": { "maruda@northraystudio": true }
}
```

この 2 つのキーは `setup.sh --plugin`（タグを固定するなら
`--plugin-ref maruda--v0.2.0`）が既存の内容を壊さずにマージして書きます。ただし
**Claude Code は settings からの自動インストールはしません**。これらのキーは
marketplace を登録して plugin を有効にするだけなので、各自が一度
`/plugin install maruda@northraystudio` を実行します。

### CLI（任意のエージェント）

```bash
# すべてのスキルを非対話で .claude/skills/ にコピー
npx skills add northraystudio/maruda --skill '*' --agent claude-code -y --copy

# 1 つだけ
npx skills add northraystudio/maruda --skill spec-doc --agent claude-code -y --copy
```

フラグなしの `npx skills add northraystudio/maruda` は対話ピッカーを開きますが、
**何も選択されていません**。Enter の前に Space で選ぶか、上のフラグを使って
ください。`--copy` はシンボリックリンクではなくコピーするので、スキルを
コミットしてチームで共有できます。

### 手動コピー

```bash
cp -r skills/spec-doc .claude/skills/spec-doc   # 1 つ
cp -r skills/* .claude/skills/                  # すべて
```

### Git submodule

```bash
git submodule add https://github.com/northraystudio/maruda.git .claude/maruda
```

スキルは `.claude/maruda/skills/` から参照します。

## 更新

この marketplace のようなサードパーティの marketplace は、**自動更新が既定で
オフ**です。入れた plugin は、更新するまで元の版のままです。先に marketplace を、
次に plugin を更新します。

```bash
claude plugin marketplace update northraystudio
claude plugin update maruda@northraystudio
```

セッションの中からなら、`/plugin` の **Marketplaces** → `northraystudio` →
**Update marketplace**、続けて **Installed** → `maruda` → **Update now** で同じことが
できます。実行中のセッションは `/reload-plugins` を実行するまで古いスキルのままです。
新しいセッションでは自動で新しい版が読み込まれます。手で更新したくない場合は、
**Marketplaces** タブで `northraystudio` の **Enable auto-update** を選びます。

- **タグに固定している場合**は、更新してもそのタグのままです。`ref`（または
  `setup.sh --plugin --plugin-ref`）を新しいタグ `maruda--v<version>` に変えてください。
- **`main` に新しい変更があるのに「already at the latest version」と出る場合**：
  更新は `.claude-plugin/plugin.json` の `version` で判定されるので、版を上げずに
  マージされた変更は届きません（`docs/adr/0006`）。
  `claude plugin uninstall maruda@northraystudio` を実行してから入れ直してください。
- `setup.sh` がプロジェクトに書いたハーネスのファイルは plugin に含まれません。
  これらは導入コマンドを再実行して更新します。差分のあるファイルは `<file>.new`
  として提案され、上書きはされません。

## `yds-` 付きの名前からの移行

`yds-` 接頭辞は廃止しました。フラットなコマンド一覧でスキルをまとめるための
接頭辞でしたが、その役目は plugin の名前空間が担います。`/yds-spec-doc` は
plugin では `/maruda:spec-doc`、`npx skills add` では `/spec-doc` になります。

- 改名前に導入したプロジェクトでは **`.claude/skills/yds-*` を削除**してから
  入れ直してください。残すと同じスキルが二重に登録されます。
- サイクルのルールも `.claude/rules/dev-skills-cycle.md` から
  `.claude/rules/maruda-cycle.md` に変わりました。`setup.sh` は自分が書いていない
  ファイルを消さないので、古い方は報告するだけです。
- submodule の置き場所も `.claude/maruda` になりました（使っている場合は
  `git mv .claude/dev-skills .claude/maruda`）。
- 引き継ぎマーカー（`<!-- gh-issue-planner:agreed-plan -->` など）と JSON 要約の
  `type` の値は旧名のままなので、既存の Issue とダッシュボードのデータはそのまま
  使えます。

リポジトリ自体は 2026-09-20 に `ymd38/dev-skills` から `northraystudio/maruda` へ
移管・改名しました。旧 URL は GitHub が転送するので、旧アドレスを指したままの
ワンライナーやクローンは動き続け、導入済みのプロジェクトで必要な作業はありません。
新しいリンクには新アドレスを使ってください。
