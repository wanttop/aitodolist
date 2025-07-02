from flask import Flask, request, jsonify
from pymongo import MongoClient
from flask_cors import CORS
import requests  # 用于智能解析接口
import json

app = Flask(__name__)
CORS(app)  # 允许所有跨域请求

client = MongoClient(
    'mongodb://qx:228386Qx%40@dds-bp1ddf599064bee41656-pub.mongodb.rds.aliyuncs.com:3717,dds-bp1ddf599064bee42248-pub.mongodb.rds.aliyuncs.com:3717/tododatabase?replicaSet=mgset-90934102'
)
db = client['tododatabase']
users_col = db['users']
tasks_col = db['tasks']

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    if not username or not password:
        return jsonify({'code': 400, 'msg': '用户名和密码不能为空'}), 400
    if users_col.find_one({'username': username}):
        return jsonify({'code': 409, 'msg': '用户已存在'}), 409
    users_col.insert_one({'username': username, 'password': password, 'avatar': ''})
    return jsonify({'code': 200, 'msg': '注册成功'})

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    user = users_col.find_one({'username': username, 'password': password})
    if user:
        return jsonify({'code': 200, 'msg': '登录成功', 'avatar': user.get('avatar', '')})
    else:
        return jsonify({'code': 401, 'msg': '用户名或密码错误'}), 401

@app.route('/change_password', methods=['POST'])
def change_password():
    data = request.json
    username = data.get('username')
    old_password = data.get('old_password')
    new_password = data.get('new_password')
    user = users_col.find_one({'username': username, 'password': old_password})
    if not user:
        return jsonify({'code': 401, 'msg': '原密码错误'}), 401
    users_col.update_one({'username': username}, {'$set': {'password': new_password}})
    return jsonify({'code': 200, 'msg': '密码修改成功'})

@app.route('/change_avatar', methods=['POST'])
def change_avatar():
    data = request.json
    username = data.get('username')
    avatar = data.get('avatar')  # 支持URL或base64
    if not users_col.find_one({'username': username}):
        return jsonify({'code': 401, 'msg': '用户不存在'}), 401
    users_col.update_one({'username': username}, {'$set': {'avatar': avatar}})
    return jsonify({'code': 200, 'msg': '头像修改成功'})

@app.route('/sync', methods=['POST'])
def sync():
    data = request.json
    username = data.get('username')
    user_tasks = data.get('tasks', [])
    if not users_col.find_one({'username': username}):
        return jsonify({'code': 401, 'msg': '未登录'}), 401
    tasks_col.delete_many({'username': username})
    for task in user_tasks:
        task['username'] = username
        tasks_col.insert_one(task)
    return jsonify({'code': 200, 'msg': '同步成功'})

@app.route('/get_tasks', methods=['GET'])
def get_tasks():
    username = request.args.get('username')
    if not users_col.find_one({'username': username}):
        return jsonify({'code': 401, 'msg': '未登录'}), 401
    user_tasks = list(tasks_col.find({'username': username}, {'_id': 0, 'username': 0}))
    return jsonify({'code': 200, 'tasks': user_tasks})

@app.route('/delete_user', methods=['POST'])
def delete_user():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    user = users_col.find_one({'username': username, 'password': password})
    if not user:
        return jsonify({'code': 401, 'msg': '用户名或密码错误'}), 401
    users_col.delete_one({'username': username})
    tasks_col.delete_many({'username': username})
    return jsonify({'code': 200, 'msg': '用户已注销，相关任务已删除'})

@app.route('/smart_parse', methods=['POST'])
def smart_parse():
    data = request.json
    user_input = data.get('text')
    history = data.get('history', [])
    tasks = data.get('tasks', [])  # 新增：获取全部任务

    # 拼接所有任务文本
    tasks_text = ""
    for t in tasks:
        title = t.get('title', '')
        due = t.get('dueDate', '')
        done = '已完成' if t.get('isDone') else '未完成'
        tags = ','.join(t.get('tags', []))
        priority = t.get('priority', '')
        tasks_text += f"- {title}（{done}，标签：{tags}，优先级：{priority}，截止：{due}）\n"

    # 拼接历史对话
    history_text = ""
    for msg in history[-10:]:
        role = "用户" if msg.get('role') == 'user' else "AI"
        history_text += f"{role}：{msg.get('text','')}\n"

    prompt = (
        "你是一个智能AI语音助手，请根据用户的所有日程（如下）和上下文与用户自然对话，必要时可引用日程内容。\n"
        f"用户所有日程：\n{tasks_text}\n"
        "历史对话如下：\n"
        f"{history_text}"
        f"用户：{user_input}\n"
        "AI："
    )

    print("发送给AI的prompt：\n", prompt)  # 新增这一行

    api_key = 'sk-a46f94de19fe45adab0536bcbe07fcb6'
    url = 'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation'
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    payload = {
        "model": "qwen-turbo",
        "input": {"prompt": prompt}
    }
    try:
        resp = requests.post(url, headers=headers, json=payload, timeout=10)
        result = resp.json()
        print("大模型原始返回：", result)
        ai_reply = result.get('output', {}).get('text', '')
        print("AI回复：", ai_reply)
        return jsonify({'code': 200, 'reply': ai_reply})
    except Exception as e:
        print("智能解析失败：", e)
        return jsonify({'code': 500, 'msg': f'智能解析失败: {str(e)}'})

@app.route('/', methods=['GET'])
def hello():
    return "阿里云MongoDB Flask API 正常运行"

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=9000)