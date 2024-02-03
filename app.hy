(require hyrule [assoc defmain])
(import os)
(import subprocess)
(import flask [Flask redirect render-template request url-for])
(import flask-sqlalchemy [SQLAlchemy])
(import flask-migrate [Migrate])

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

  (render-template "index.html"
                   #** {"streams" streams
                        "currently_playing" currently-playing
                        "none_selected" none-selected}))

(defn [(app.route "/play" :methods ["POST"])] play []
  (when (request.form.get "stream")
    (do
      (print "got here 2")
      (setv stream-id (int (request.form.get "stream")))
      (setv stream (Stream.query.get-or-404 stream-id))
      (setv submitted (request.form.get "submit"))
      (setv deleted (request.form.get "delete"))

      (if (and submitted (not stream.currently-playing))
          (do
            (setv streams (Stream.query.all))
            (for [stream_ streams]
              (setv stream_.currently-playing False))

            (db.session.commit)

            (subprocess.call ["mpc" "clear"])
            (subprocess.call ["mpc" "add" stream.url])
            (subprocess.call ["mpc" "play"])

            (setv stream.currently-playing True)
            (db.session.commit))

          (when deleted
            (do
              (when stream.currently-playing
                (subprocess.call ["mpc" "clear"])
                (subprocess.call ["mpc" "stop"]))

              (db.session.delete stream)
              (db.session.commit))))))

  (return (redirect (url-for "index"))))

(defn [(app.route "/stop" :methods ["POST"])] stop []
  (setv streams (Stream.query.all))
  (for [stream streams]
    (setv stream.currently-playing False))

  (db.session.commit)
  (subprocess.call ["mpc" "stop"])

  (return (redirect (url-for "index"))))

(defn [(app.route "/create" :methods ["GET" "POST"])] create []
  (setv stream-name (request.form.get "stream_name"))
  (setv stream-url (request.form.get "stream_url"))
  (setv stream (Stream :name stream-name :url stream-url :currently-playing False))
  (db.session.add stream)
  (db.session.commit)

  (return (redirect (url-for "index"))))
