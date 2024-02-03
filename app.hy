(require hyrule [assoc defmain])
(import logging)
(import os)
(import subprocess)
(import sys)
(import flask [Flask redirect render_template request url_for])
(import flask-sqlalchemy [SQLAlchemy])
(import flask-migrate [Migrate])

(.addHandler (logging.getLogger) (logging.StreamHandler))
(.setLevel (logging.getLogger) logging.INFO)

(setv app (Flask __name__))
(setv path (os.path.join (os.path.expanduser "~/dbs") "development.db"))
(assoc app.config "SQLALCHEMY_DATABASE_URI" f"sqlite:///{path}")
(assoc app.config "SQLALCHEMY_TRACK_MODIFICATIONS" False)
(setv db (SQLAlchemy app))
(setv migrate (Migrate app db))

(defmacro defcolumn [name type #* args]
  (if args
      `(setv ~name (db.Column ~type #** {~@args}))
      `(setv ~name (db.Column ~type))))

(defclass Stream [db.Model]
  (defcolumn id db.Integer "primary_key" True)
  (defcolumn name (db.String 240) "unique" True "nullable" False)
  (defcolumn url (db.String 240) "unique" True "nullable" False)
  (defcolumn currently-playing db.Boolean "unique" False "default" False)
  (defcolumn created
    (db.DateTime :timezone True)
    "unique" False
    "default" (db.func.now))

  (defcolumn updated
    (db.DateTime :timezone True)
    "unique" False
    "default" (db.func.now))

  (defn __init__ [self name url currently-playing]
    (setv self.name name)
    (setv self.url url)
    (setv self.currently-playing currently-playing))

  (defn __repr__ [self]
    f"<Stream {self.name}>"))

(defn [(app.route "/")] index []
  (setv streams (Stream.query.order_by Stream.name))
  (setv currently-playing None)
  (for [stream streams]
    (if stream.currently-playing
        (do
          (setv currently-playing stream)
          (break))
        (setv currently-playing None)))
  (setv none-selected True)
  (when currently-playing
    (setv none-selected False))

  (render_template "index.html"
                   #** {"streams" streams
                        "currently_playing" currently-playing
                        "none_selected" none-selected}))
