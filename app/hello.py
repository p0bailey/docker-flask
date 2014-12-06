#!flask/bin/python
from flask import render_template
from flask import Flask

my_app = Flask(__name__)

@my_app.route('/')
def hello():
    return render_template('hello.html')

if __name__ == '__main__':
    my_app.run(host='0.0.0.0')
