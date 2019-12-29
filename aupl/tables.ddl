drop table if exists tracks;
//
create table tracks
(
    idx integer primary key not null,
	relPath text not null,
    artist text,
	track text,
	album text,
	lastPlayed big unsigned int not null default 0,
	timesPlayed int not null default 0
);
create unique index relPath_index ON tracks(relPath);
//
create unique index artist_index ON tracks(artist,idx);
//
create unique index track_index ON tracks(track,idx);
//
create unique index album_index ON tracks(album,idx);
//
create unique index lastPlayed_index ON tracks(lastPlayed,idx);
//
