#!flask/bin/python

from flask import Flask
my_app = Flask(__name__)

@my_app.route('/')
def hello_world():
    return 'Hello World!'

if __name__ == '__main__':
    my_app.run(host='0.0.0.0')
