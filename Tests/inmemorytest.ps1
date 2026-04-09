$query = 'CREATE TABLE "characters" (
    "id"    INTEGER,
    "name"    TEXT UNIQUE,
    "guild"    INTEGER,
    "TestNull"    TEXT NULL
);'

$c = New-PSqliteConnection

# Invoke-PSqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText $query -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText "INSERT INTO characters (id, name, guild) VALUES (1, 'John', 1);" -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive -As PSCustomObject
Invoke-PSqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive -As OrderedDictionary

$c.Close()

$c = New-PSqliteConnection -DatabaseFile 'test.sqlite'

# Invoke-PSqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText $query -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText "INSERT INTO characters (id, name, guild) VALUES (1, 'John', 1);" -keepAlive
Invoke-PSqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
# Invoke-PSqliteQuery -SqliteConnection $c -CommandText "DELETE FROM characters WHERE id = 1;" -keepAlive
