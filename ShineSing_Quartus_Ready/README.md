# V9 — 使用小组 WAV 采样的版本

基线为 V8x `MTRX3700_Assignment2_Group13-main_fit_fixed.zip`。默认分类器改用你们提供的 8 段录音；原始压缩包和 sample 目录没有修改。

## 目录和数据流

| 路径 | 用途 |
|---|---|
| `data/recordings/*.wav` | 原始小组录音，ee / ah / oo / aw 各两段 |
| `tools/train_recordings.py` | WAV 转换、调用 RTL 提取、按录音分组验证、生成模板 |
| `tb/extract_recording_features.sv` | 复用原 H95 提取框架，执行实际 FIR → 降采样 → 窗 → FFT → 24 维 log-Mel |
| `rtl/templates.svh`、`templates.hex` | 默认硬件使用的 4 类 × 4 模板 × 24 维常量 |
| `rtl/templates_training.json` | 采样哈希、特征 RTL 哈希、验证结果；不是课程报告 |
| `assets/recordings/` | 实际 RTL 特征、输入清单、Python 独立计算的分类期望值 |
| `tb/tb_recording_classifier.sv` | 校验分类、拒绝、置信度、上电与复位保留模板 |
| `assets/h95/templates.svh` | 旧 H95 测试专用模板，避免旧测试与小组模板混用 |

训练复用 Ed 提供的 `provided_train_templates.py` 中 SAD 距离、逐维中位数模板训练和 SV 导出。硬件仍使用 V8x 的 MODE=4、D=24、LOG_SCALE=64、NT=4、M=3、rho=7/10、DMAX=65000，没有引入神经网络或运行时 Python。

## 本次实际验证

26 项 RTL 回归、5 项录音处理单元测试、2 项原模板导入测试、Intel RAM 原语检查均通过。VGA 功能演示完成 18 张实际 RTL 画面和游戏动画。

Quartus 18.1 完整编译成功（0 errors、105 warnings），已附 `output_files/shine_sing.sof`。ALM 74%、RAM 块 81%、DSP 36%；现有 SDC 约束下最差 setup slack 为 2.560 ns、hold slack 为 0.119 ns，汇总时序项目均非负。详细结果在 `verification.json` 和 `docs/evidence/`。这些结果不替代实际麦克风和显示器的上板验证。

## 已训练版本怎么用

打开 `shine_sing.qpf`，编译并下载**这个版本新生成的** SOF。上电已经有四类模板，不需要 KEY3 现场录入。KEY0 复位保留模板。复位后保持环境安静约 1 秒，让原有音量门完成噪声标定，然后对着板载音频输入发 ee、ah、oo、aw，HEX2 分别应显示 0、1、2、3；拒绝或静音时为空白。

手机/电脑录音与板上麦克风的频响、增益和环境会不同。离线分组验证与板上效果分开看；现场仍需用你们的声音检查四类识别。

## 在 Ed 重跑测试

把 ZIP 解压后的项目文件放到 Assignment 2 的 workspace 根目录，终端先确认 `verilator --version` 是课程的 5.050。执行：

```sh
python3 -m pip install -r requirements.txt
python3 tools/check_project.py --require-trained
python3 tools/test_recordings.py
python3 tools/test_saved_templates.py
sh run_ed.sh
```

只检查本次更换的模板，可运行：

```sh
python3 tools/run_tests.py --sim verilator tb_recording_classifier tb_classifier_saved
```

测试需要已有的模板和小型特征文件，**不需要重新训练，也不需要 H95 下载包**。`tb_h95_classifier` 仅检查保留下来的 H95 基线 fixture，不代表当前默认模板识别 H95 的准确率。

原 VGA 图像/游戏模块保持 V8x 结构。可先运行 `sh run_ed.sh tb_video_source tb_system`，再运行：

```sh
mkdir -p build/demo
python3 tools/run_tests.py --sim verilator demo_visual
python3 tools/run_demo.py --render-only
```

生成的 `docs/evidence/demo/*.png` 和 `game_steps.gif` 可在 Ed 文件区打开。这是 RTL 视频流与合成音频事件的功能演示，不是你们录音的识别演示，也不验证显示器、VGA 引脚或实际 PLL。完整硬件 VGA 仍需上板确认。

## 换一批录音 / 重新训练

将每个元音至少两段独立 WAV 放进 `data/recordings`，例如 `ee.wav`、`ee1.wav`、`ah-001.wav`。也支持 `ee/人名_次数.wav` 这样的分类子目录。只放计划参与训练的文件，文件名必须准确标注元音；不要混进 H95。建议每段持续 1–2 秒，包含稳定元音，多次单独录制。

Ed / Linux：

```sh
python3 tools/train_recordings.py --samples data/recordings --sim verilator
```

Windows + ModelSim：

```powershell
python tools/train_recordings.py --samples data/recordings --sim modelsim
```

支持 8/16/24/32-bit 整数 PCM WAV。选择能量最高的单个声道，避免反相双声道抵消；抗混叠重采样到 48 kHz 后按固定幅值转成 PCM16。每个完整 4096 点输入帧对应 85.33 ms；连续输入实际 RTL，保持 FIR 历史。训练只选 RMS ≥ max(128, 该录音最高整帧 RMS × 0.40) 的帧，排除弱尾音；这是离线选样规则，不替代板上原有音量门。

验证把**完整录音**分成两折，训练集和验证集不共享同一文件；模板种子只按训练误差选取。你们确认每个元音的两段来自不同的人，因此此处主要检查每类换人的泛化能力；文件名尚未提供跨元音统一的说话人身份。

最终部署使用全部录音，每类给两段录音**各两个模板名额**，避免长录音挤占另一个人的名额。每类不超过四段时平均分配四个名额；更多录音时按每段相同权重汇总后聚类。少于所需帧数时会复制已有模板填满硬件槽，复制不算新增训练数据。

本批录音按整段隔离的两折验证：51 个有效帧，6 正确、3 错误、42 拒绝。这个结果提示只训练一个人的声音不足以覆盖另一个人；最终同时包含两个人的模板，不能用训练集成绩替代新录音/现场验证。不要为了提高这个小验证集的分数，直接放宽拒绝阈值。

重新训练会更新默认模板及其测试 fixture，因此需重新跑测试、重新编译 Quartus；旧 SOF 不会自动更新。信号处理 RTL 改动后，`check_project.py --require-trained` 会通过哈希检查阻止继续使用过期特征模板。

`tools/train_saved_templates.py` 仍可导入板上 SignalTap 的四类 CSV，作为后续麦克风校准路径。`tools/build_h95_templates.sh` 保留为旧数据集实验入口，不是当前默认流程。
