drop table if exists tracks;
//
create table tracks
(
    idx integer primary key not null,
	relPath text not null,
    artist text,
	track text,
    trackNumber int,
    discNumber int not null default 1,
    durationSecs int,
	album text,
    lastPlayed big unsigned int not null default 0,
    created big unsigned int not null default 0,
	timesPlayed int not null default 0
);
create unique index relPath_index ON tracks(relPath);
//
create unique index artist_index ON tracks(artist,album,trackNumber,idx);
//
create unique index track_index ON tracks(track,idx);
//
create unique index album_index ON tracks(album,discNumber,trackNumber,idx);
//
create unique index lastPlayed_index ON tracks(lastPlayed,idx);
//
create unique index created_index ON tracks(created,idx);
//
create unique index timesPlayed_index ON tracks(timesPlayed,idx);
//
