# Music Player 設計書

## 1. レイヤー構造

```
main.dart
  └─ MusicListScreen（Scaffold, PageView）
       ├─ ConfigSetter（AppBar: 速度Slider / 検索 / リロード / 日付フィルタ）
       ├─ SideUI（左パネル: ディレクトリ別 frequency 設定）
       ├─ MusicListBody（メイン: ReorderableListView）
       │    └─ MusicTile（1行）
       └─ MiniPlayer（下部: シークバー + 再生制御）
```

| レイヤー | ディレクトリ | 責務 |
|---------|-------------|------|
| **モデル** | `classes/` | `MusicItem`（id + key で一意識別可能な曲データ） |
| **サービス** | `services/` | `AudioFileService`（ファイルI/O）, `PlaybackService`（音声再生の司令塔） |
| **コントローラ** | `controllers/` | `MusicPlayerController`（キュー・状態管理）, `MediaPlayerController`（その継承） |
| **画面** | `screens/` | Scaffold 定義、ページ遷移 |
| **部品** | `widgets/` | UI パーツ（表示のみ） |

---

## 2. クラス図

```
┌─────────────────────────────────────────────────┐
│ MusicItem                                       │
│  id (一意), key (Widget用)                      │
│  path, title, directory, artist                 │
│  integratedLoudness, truePeak, modified         │
│  isMedia, adjustedVolume                        │
│  loadTags(), loadVolumeFromCache()              │
│  saveProgress(), loadProgress()                 │
│  loadTotalDuration(), detectVolume()            │
│  toMediaItem()                                  │
│  == / hashCode は id ベース                      │
└──────────────┬──────────────────────────────────┘
               │ List<MusicItem>（id で一意識別、コピー時も新しい id）
               ▼
┌─────────────────────────────────────────────────┐
│ MusicPlayerController (ChangeNotifier)           │
│  playQueue: List<MusicItem>                      │
│  allLoadedFiles: List<MusicItem>                 │
│  shuffleConfig: Map<String, ShuffleConfig>       │
│  filterDate: DateTime?                           │
│  play(), playNext(), playNow(), addNext()        │
│  reorder(), moveMusicUp/Down/Next()              │
│  removeMusic(), deleteMusicFile()                │
│  loadFiles(), setMusicFiles(), clearFiles()      │
│  togglePlayPause(), seek(), timeSkip()           │
│  └─ delegate: PlaybackSession (経由 PlaybackService)
└──────────────┬──────────────────────────────────┘
               │ extends
               ▼
┌─────────────────────────────────────────────────┐
│ MediaPlayerController                             │
│  (MusicPlayerController + SessionType.media)      │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ PlaybackSession                                  │
│  selectedMusic: MusicQueueItem?                  │
│  position / duration: ValueNotifier<Duration>    │
│  isPlaying, playbackSpeed                        │
└──────────────┬──────────────────────────────────┘
               │ Map<SessionType, PlaybackSession>
               ▼
┌─────────────────────────────────────────────────┐
│ PlaybackService (ChangeNotifier, Singleton)      │
│  _audioPlayer: AudioPlayer (just_audio)          │
│  play(), switchSession(), _loadAndPlay()         │
│  togglePlayPause(), seek(), setSpeed()           │
│  activeType, playingType                         │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ AudioFileService (静的メソッドのみ)               │
│  loadMusicFiles() → List<MusicItem>              │
│  requestPermissions()                            │
└─────────────────────────────────────────────────┘
```

---

## 3. データフロー

### ファイル読み込み〜再生
```
AudioFileService.loadMusicFiles()
  → List<MusicItem>
  → MusicPlayerController.loadFiles()
     → playQueue = items.map(MusicQueueItem.new)
  → UI が ListenableBuilder で再描画
  → ユーザータップ → controller.play(queueItem)
     → PlaybackService.play()
        → _loadAndPlay() で just_audio にセット
```

### 次曲自動再生
```
just_audio ProcessingState.completed
  → MusicPlayerController.playNext()
     → playQueue.indexWhere(m => m.id == selectedMusic.id)
     → (index + 1) % length → play()
```

**バグ修正ポイント**: 旧コードは `m.path == selectedMusic.path` で比較していたため、
同一パスの曲がキューに複数あると常に最初の位置を返し不安定だった。
現在はインスタンスごとの一意な `m.id == selectedMusic.id` で比較する。

### playNow / addNext
```
playNow(MusicItem)
  → 同名パスをキューから削除
  → selectedMusic.id の直後に MusicQueueItem を挿入
  → 再生
addNext(MusicItem) も同様（即再生しない）
```

### キュー再構築（setMusicFiles）
```
setMusicFiles()
  → ファイル再スキャン
  → 日付ソート / フィルタ適用
  → ディレクトリ別にグループ化
  → dirIterFiltered() で weighted round-robin
  → diffutil で既存キューとの差分を計算
     → Insert / Remove / Move を適用
  → playQueue を差し替え
```

---

## 4. 各コンポーネントの役割

| ファイル | 役割 |
|---------|------|
| `main.dart` | アプリ起動、JustAudioBackground 初期化、MaterialApp |
| `music.dart` | `MusicItem`（曲データ）, `MusicQueueItem`（キューエントリ: id で一意識別） |
| `music_player_controller.dart` | キュー操作・状態管理・シャッフル設定・ルーティング。ChangeNotifier |
| `media_player_controller.dart` | 継承のみ。sessionType = media |
| `playback_service.dart` | 音声再生の実処理。Singleton。music/media 2セッション管理 |
| `audio_file_service.dart` | 静的メソッド。ファイル一覧スキャン + タグ読み込み |
| `music_list_screen.dart` | PageView で music/media タブ切り替え。MiniPlayer 表示制御 |
| `media_player_screen.dart` | メディア専用全画面プレイヤー（90度回転、倍速操作） |
| `music_list_body.dart` | ReorderableListView + コンテキストメニュー（移動・削除） |
| `music_tile.dart` | 1行分の表示（タイトル・アーティスト・進捗・上下ボタン） |
| `mini_player.dart` | 下部固定のシークバー + 再生/一時停止/スキップ |
| `search_music_screen.dart` | 全曲リアルタイム検索 + playNow/addNext |
| `upside_config.dart` | AppBar: 速度Slider / 検索 / リロード / 日付フィルタ設定 |
| `side_ui.dart` | 左パネル: ディレクトリ別 frequency 表示 |
| `side_ui_mix_custum.dart` | frequency 増減ステッパー |
| `media_progress.dart` | 未使用（旧・縦スライダー） |

---

## 5. キュー操作一覧

| 操作 | メソッド | 比較キー |
|------|---------|---------|
| 次曲へ | `playNext()` | `selectedMusic.id` |
| 即再生 + 移動 | `playNow(MusicItem)` | 削除: `path`, 挿入位置: `selectedMusic.id` |
| 次に追加 | `addNext(MusicItem)` | 削除: `path`, 挿入位置: `selectedMusic.id` |
| 削除 | `removeMusic(MusicItem)` | `music.id` |
| 次に移動 | `moveMusicNext(index)` | `selectedMusic.id` |
| 上下移動 | `moveMusicUp/Down(index)` | インデックス直接 |
| ドラッグ | `reorder(old, new)` | インデックス直接 |

---

## 6. ShuffleConfig / ディレクトリ重み付け

```
shuffleConfig: Map<String, ShuffleConfig>
  └─ ShuffleConfig { name, frequency (0-5), shuffle (bool) }

dirIterFiltered(): weighted round-robin
  → frequency 比でディレクトリを選択、1曲ずつピック
  → 同一パス重複回避（usedPaths Set）
  → queue 再構築時は diffutil で差分適用
```
