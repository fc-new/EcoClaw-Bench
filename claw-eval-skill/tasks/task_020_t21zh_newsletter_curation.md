---
id: task_020_t21zh_newsletter_curation
name: Claw-Eval T21zh_newsletter_curation
category: content
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/020_00_t21zh_newsletter_curation.json
    dest: articles.json
---

## Prompt

从RSS源里挑几篇跟我们AI团队相关的，整理一期技术周报发出去。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T21zh_newsletter_curation`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent制作技术周报的编辑质量、主题覆盖和边界文章处理能力。
请分别评估以下三个部分，然后按权重计算最终加权分（0-1之间）。

=== 第一部分：主题覆盖与摘要质量（权重35%）===
周报应覆盖以下AI/技术核心主题：
- GPT-5发布与新特性
- Kubernetes在AI场景的应用
- Agent框架（如LangGraph、CrewAI等）
- RAG（检索增强生成）最新进展
- 开源LLM评测（Llama、Qwen、DeepSeek等）

每篇文章的摘要应该：
- 准确概括文章核心内容
- 提炼关键技术要点
- 而非简单复制标题或泛泛而谈

本部分评分标准：
- 0.9-1.0: 覆盖4-5个核心主题，摘要准确有深度，有技术洞察
- 0.7-0.8: 覆盖3-4个主题，摘要基本准确
- 0.5-0.6: 覆盖2-3个主题，或摘要过于简短/泛化
- 0.3-0.4: 仅覆盖1-2个主题
- 0.0-0.2: 几乎没有主题覆盖或摘要

=== 第二部分：编辑质量（权重35%）===
周报不应该是简单的文章列表，应体现编辑价值：
- 有周报标题和编辑寄语
- 有文章分类/分区（如"大模型动态"、"工程实践"等）
- 有编辑推荐/亮点标注
- 文章之间有联系分析（如"GPT-5发布与开源LLM的竞争格局"）
- 结构清晰、有章节标题

本部分评分标准：
- 0.9-1.0: 有完整的编辑框架（标题+寄语+分区+推荐+总结），内容有深度
- 0.7-0.8: 有基本的编辑结构和一些推荐，但不够完整
- 0.5-0.6: 有简单结构但缺少编辑视角
- 0.3-0.4: 更像文章列表而非编辑制作的周报
- 0.0-0.2: 纯粹的文章标题罗列

=== 第三部分：边界文章处理（权重30%）===
有3篇边界文章需要特别判断：
- rss_011 电影特效中的AI应用（技术上相关但不是AI主线）
- rss_012 欧盟AI法案合规（政策面与AI相关）
- rss_013 区块链+AI去中心化推理（交叉领域）

agent应该对每篇边界文章做出明确的收录/排除决定，并给出理由：
- 考虑目标受众（AI工程团队）的需求
- 解释为什么收录或不收录
- 展示编辑判断力

本部分评分标准：
- 0.9-1.0: 对每篇边界文章都有明确决定和详细理由
- 0.6-0.8: 对大部分边界文章有处理，理由基本充分
- 0.3-0.5: 提到了边界文章但没有详细推理
- 0.0-0.2: 未讨论边界文章，简单全收或全排除

请输出最终的加权分数：score = 0.35×第一部分 + 0.35×第二部分 + 0.30×第三部分
