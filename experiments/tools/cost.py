import json
import glob
import os

# Pricing tables (USD per million tokens)
PRICING = {
    'gmn/gpt-5.4': {
        'input': 2.50,
        'output': 15.00,
        'cache_read': 0.25,
        'cache_write': 0.0,
    },
    'minimax/MiniMax-M2.7': {
        'input': 0.2917,
        'output': 1.1667,
        'cache_read': 0.0583,
        'cache_write': 0.3646,
    },
}

def calc_cost(usage, pricing):
    inp = usage.get('input_tokens', 0)
    out = usage.get('output_tokens', 0)
    cr = usage.get('cache_read_tokens', 0)
    cw = usage.get('cache_write_tokens', 0)
    cost = (
        inp * pricing['input'] / 1_000_000
        + out * pricing['output'] / 1_000_000
        + cr * pricing['cache_read'] / 1_000_000
        + cw * pricing.get('cache_write', 0) / 1_000_000
    )
    return round(cost, 6)

results_root = 'results/raw/pinchbench'
updated = 0

for json_path in sorted(glob.glob(f'{results_root}/**/*.json', recursive=True)):
    with open(json_path) as f:
        data = json.load(f)
    
    model = data.get('model', '')
    pricing = PRICING.get(model)
    if not pricing:
        print(f'  ⏭  {os.path.basename(json_path)}: unknown model \"{model}\", skipping')
        continue
    
    total_cost = 0.0
    for task in data.get('tasks', []):
        usage = task.get('usage', {})
        task_cost = calc_cost(usage, pricing)
        usage['cost_usd'] = task_cost
        total_cost += task_cost
    
    # Update efficiency summary
    eff = data.get('efficiency', {})
    eff['total_cost_usd'] = round(total_cost, 6)
    num_tasks = len(data.get('tasks', []))
    if num_tasks > 0:
        eff['cost_per_task_usd'] = round(total_cost / num_tasks, 6)
    total_tokens = eff.get('total_tokens', 0)
    all_scores = [float(t['grading']['mean']) for t in data.get('tasks', [])]
    total_score = sum(all_scores)
    if total_cost > 0:
        eff['score_per_dollar'] = round(total_score / total_cost, 4)
    
    # Update per_task efficiency
    for pt in eff.get('per_task', []):
        for task in data.get('tasks', []):
            if task['task_id'] == pt['task_id']:
                pt['cost_usd'] = task['usage'].get('cost_usd', 0.0)
                break
    
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f'  ✅ {os.path.basename(json_path)}: model={model}, total_cost=\${total_cost:.4f}')
    updated += 1

print(f'\nUpdated {updated} files')