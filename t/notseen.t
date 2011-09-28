print "1..10\n";
print "ok 1\n";
print "ok 2 - hello text\n";
# not seen 3
print "not ok 4 - i didn't seen number 3 # todo text after type - reason text\n";
print "not ok 4 - i didn't seen number 3 # todo text\n# second line\n";
print "ok 5 # skip skipping number 5\n";
print "not ok 6\n";
print "ok 7 - seven # myowntype-ok mytext after type\n # second line\n";
print "not ok 8 - eight # myowntype-not-ok mytext after type\n# second line\n";
print "not ok 9\n";
# not seen 10

# parrot-temp> perl t\harnessnew t\notseen.t --yaml
