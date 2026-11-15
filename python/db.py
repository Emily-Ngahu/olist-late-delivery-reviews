import getpass
import os
from pathlib import Path

import pymysql


def connect_mysql(database="olist", local_infile=False):
    """Open a connection. database=None connects without choosing a database."""
    host = os.environ.get("MYSQL_HOST", "127.0.0.1")
    port = int(os.environ.get("MYSQL_PORT", "3306"))
    user = os.environ.get("MYSQL_USER", "root")
    extra = {"local_infile": local_infile}
    if database:
        extra["database"] = database

    if "MYSQL_PASSWORD" in os.environ:
        return pymysql.connect(host=host, port=port, user=user,
                               password=os.environ["MYSQL_PASSWORD"], **extra)

    cnf = Path.home() / ".my.cnf"
    if cnf.exists():
        if "MYSQL_PORT" in os.environ:
            extra["port"] = port
        return pymysql.connect(read_default_file=str(cnf), **extra)

    password = getpass.getpass(f"MySQL password for {user}@{host}: ")
    return pymysql.connect(host=host, port=port, user=user, password=password, **extra)
