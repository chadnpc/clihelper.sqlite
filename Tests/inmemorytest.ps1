$query = 'CREATE TABLE "characters" (
    "id"    INTEGER,
    "name"    TEXT UNIQUE,
    "guild"    INTEGER,
    "TestNull"    TEXT NULL
);'

$c = New-SqliteConnection

# Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText $query -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText "INSERT INTO characters (id, name, guild) VALUES (1, 'John', 1);" -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive -As PSCustomObject
Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive -As OrderedDictionary

$c.Close()

$c = New-SqliteConnection -DatabaseFile 'test.sqlite'

# Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText $query -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText "INSERT INTO characters (id, name, guild) VALUES (1, 'John', 1);" -keepAlive
Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
# Invoke-SqliteQuery -SqliteConnection $c -CommandText "DELETE FROM characters WHERE id = 1;" -keepAlive
