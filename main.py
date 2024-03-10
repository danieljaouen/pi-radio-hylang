#!/usr/bin/env python

import hy
import os
from app import app

if __name__ == "__main__":
    if os.getenv('FLASK_DEBUG'):
        app.run(debug=True)
    else:
        app.run(debug=False)
