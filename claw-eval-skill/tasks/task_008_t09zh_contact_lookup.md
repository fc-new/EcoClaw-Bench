---
id: task_008_t09zh_contact_lookup
name: Claw-Eval T09zh_contact_lookup
category: communication
grading_type: llm_judge
timeout_seconds: 300
workspace_files:
  - source: assets/claw_eval/008_00_t09zh_contact_lookup.json
    dest: contacts.json
---

## Prompt

帮我查一下技术部张伟的联系方式。

Please complete the task in the workspace.

## Expected Behavior

The agent should complete this Claw-Eval task correctly.
Language: `zh`
Dataset split: `general`
Original task id: `T09zh_contact_lookup`

## Grading Criteria

- [ ] Understands the task request
- [ ] Produces correct and complete result
- [ ] Uses workspace fixtures appropriately when provided

## LLM Judge Rubric

评估agent在面对多个相似姓名的搜索结果时，消歧义的质量。

背景：用户查找"技术部张伟"的联系方式。搜索结果包含多个相似姓名：
- 张伟 (c_001, 技术部, 高级工程师) — 正确目标
- 张维 (c_007, 技术部, 初级工程师) — 同音干扰项，同部门
- 张卫、张薇、张伟东等 — 其他相似名字

消歧义的关键考察点：
1. 是否列出了多个搜索结果，让用户了解有同名/近似名的人
2. 是否明确区分了张伟(高级工程师)和张维(初级工程师)这两个同部门的人
3. 是否清楚地推荐了正确的张伟(c_001)，而不是张维(c_007)
4. 是否使用了部门筛选来主动缩小范围
5. 是否提供了位置等额外有用信息

重要：如果agent推荐了错误的联系人（张维/c_007而非张伟/c_001），应该严重扣分。

评分标准：
- 0.9-1.0: 列出了多个结果，明确区分了张伟和张维，正确推荐了目标，解释了区分理由
- 0.7-0.8: 正确推荐了目标但区分解释不够清晰
- 0.4-0.6: 提到了多个结果但消歧义不够明确
- 0.1-0.3: 没有有效消歧义，或推荐了错误联系人
- 0.0: 完全没有消歧义分析
