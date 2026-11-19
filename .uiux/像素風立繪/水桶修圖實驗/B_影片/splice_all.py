"""一次處理好幾張：下載 H3 影片、各自跑 video_splice.py，同時跑 4 張。

用法：python splice_all.py 清單.json
清單.json：{"代號": "影片網址", ...}。影片存成 {代號}_6s_raw.mp4，已經下載過的不再抓。
哪一張失敗就把它的錯誤印出來，最後列出失敗的代號；有失敗就以非零結束。
"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
WORKERS = 4


def one(name, url):
    video = os.path.join(HERE, name + '_6s_raw.mp4')
    if not os.path.isfile(video):
        subprocess.run(['curl', '-sf', '-o', video, url], check=True)
    run = subprocess.run(
        [sys.executable, os.path.join(HERE, 'video_splice.py'), video, name],
        capture_output=True, text=True, encoding='utf-8', env={**os.environ, 'PYTHONIOENCODING': 'utf-8'},
    )
    return name, run.returncode, (run.stdout + run.stderr).strip()


def main():
    if len(sys.argv) != 2:
        raise SystemExit('用法：python splice_all.py 清單.json')
    with open(sys.argv[1], encoding='utf-8') as f:
        jobs = json.load(f)
    failed = []
    with ThreadPoolExecutor(WORKERS) as pool:
        for name, code, log in pool.map(lambda item: one(*item), jobs.items()):
            print('==', name, '成功' if code == 0 else '失敗')
            print(log)
            if code != 0:
                failed.append(name)
    if failed:
        raise SystemExit('失敗：' + '、'.join(failed))


if __name__ == '__main__':
    main()
