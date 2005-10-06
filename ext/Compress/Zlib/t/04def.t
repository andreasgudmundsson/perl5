BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir 't' if -d 't';
	@INC = ("../lib", "lib");
    }
}

use lib 't';
use strict;
use warnings;
use bytes;

use Test::More ;
use ZlibTestUtils;

BEGIN 
{ 
    # use Test::NoWarnings, if available
    my $extra = 0 ;
    $extra = 1
        if eval { require Test::NoWarnings ;  import Test::NoWarnings; 1 };

    plan tests => 1775 + $extra ;

    use_ok('Compress::Zlib', 2) ;

    use_ok('IO::Compress::Gzip', qw($GzipError)) ;
    use_ok('IO::Uncompress::Gunzip', qw($GunzipError)) ;

    use_ok('IO::Compress::Deflate', qw($DeflateError)) ;
    use_ok('IO::Uncompress::Inflate', qw($InflateError)) ;

    use_ok('IO::Compress::RawDeflate', qw($RawDeflateError)) ;
    use_ok('IO::Uncompress::RawInflate', qw($RawInflateError)) ;

}

use IO::Handle qw(SEEK_SET SEEK_CUR SEEK_END);


our ($UncompressClass);


sub myGZreadFile
{
    my $filename = shift ;
    my $init = shift ;


    my $fil = new $UncompressClass $filename,
                                    -Strict   => 1,
                                    -Append   => 1
                                    ;

    my $data = '';
    $data = $init if defined $init ;
    1 while $fil->read($data) > 0;

    $fil->close ;
    return $data ;
}

# Check zlib_version and ZLIB_VERSION are the same.
is Compress::Zlib::zlib_version, ZLIB_VERSION, 
    "ZLIB_VERSION matches Compress::Zlib::zlib_version" ;



foreach my $CompressClass ('IO::Compress::Gzip',     
                           'IO::Compress::Deflate', 
                           'IO::Compress::RawDeflate')
{

    title "Testing $CompressClass";

    # Buffer not writable
    eval qq[\$a = new $CompressClass(\\1) ;] ;
    like $@, mkEvalErr("^$CompressClass: output buffer is read-only") ;
        
    my $out = "" ;
    eval qq[\$a = new $CompressClass \$out ;] ;
    like $@, mkEvalErr("^$CompressClass: output filename is undef or null string");
        
    $out = undef ;
    eval qq[\$a = new $CompressClass \$out ;] ;
    like $@, mkEvalErr("^$CompressClass: output filename is undef or null string");
        
    my $x ;
    my $gz = new $CompressClass(\$x); 

    foreach my $name (qw(read readline getc))
    {
        eval " \$gz->$name() " ;
        like $@, mkEvalErr("^$name Not Available: File opened only for output");
    }

    eval ' $gz->write({})' ;
    like $@, mkEvalErr("^${CompressClass}::write: not a scalar reference");
    #like $@, mkEvalErr("^${CompressClass}::write: input parameter not a filename, filehandle, array ref or scalar ref");

    eval ' $gz->syswrite("abc", 1, 5)' ;
    like $@, mkEvalErr("^${CompressClass}::write: offset outside string");

    eval ' $gz->syswrite("abc", 1, -4)' ;
    like $@, mkEvalErr("^${CompressClass}::write: offset outside string");
}


foreach my $CompressClass ('IO::Compress::Gzip',
                           'IO::Compress::Deflate',
                           'IO::Compress::RawDeflate',
                         )
{
    $UncompressClass = getInverse($CompressClass);
    my $Error = getErrorRef($CompressClass);
    my $UnError = getErrorRef($UncompressClass);

    title "Testing $UncompressClass";

    my $out = "" ;
    eval qq[\$a = new $UncompressClass \$out ;] ;
    like $@, mkEvalErr("^$UncompressClass: input filename is undef or null string");
        
    $out = undef ;
    eval qq[\$a = new $UncompressClass \$out ;] ;
    like $@, mkEvalErr("^$UncompressClass: input filename is undef or null string");

    my $lex = new LexFile my $name ;

    ok ! -e $name, "  $name does not exist";
    
    eval qq[\$a = new $UncompressClass "$name" ;] ;
    is $$UnError, "input file '$name' does not exist";

    my $gc ;
    my $guz = new $CompressClass(\$gc); 
    $guz->write("abc") ;
    $guz->close();

    my $x ;
    my $gz = new $UncompressClass(\$gc); 

    foreach my $name (qw(print printf write))
    {
        eval " \$gz->$name() " ;
        like $@, mkEvalErr("^$name Not Available: File opened only for intput");
    }

}

foreach my $CompressClass ('IO::Compress::Gzip',
                           'IO::Compress::Deflate',
                           'IO::Compress::RawDeflate',
                         )
{
    $UncompressClass = getInverse($CompressClass);
    my $Error = getErrorRef($CompressClass);
    my $ErrorUnc = getErrorRef($UncompressClass);


    title "Testing $CompressClass and $UncompressClass";

    {
        my ($a, $x, @x) = ("","","") ;

        # Buffer not a scalar reference
        eval qq[\$a = new $CompressClass \\\@x ;] ;
        like $@, mkEvalErr("^$CompressClass: output parameter not a filename, filehandle or scalar ref");
            
        # Buffer not a scalar reference
        eval qq[\$a = new $UncompressClass \\\@x ;] ;
        like $@, mkEvalErr("^$UncompressClass: input parameter not a filename, filehandle, array ref or scalar ref");
    }
        
    foreach my $Type ( $CompressClass, $UncompressClass)
    {
        # Check error handling with IO::Compress::Deflate and IO::Uncompress::Inflate

        my ($a, $x, @x) = ("","","") ;

        # Odd number of parameters
        eval qq[\$a = new $Type "abc", -Output ] ;
        like $@, mkEvalErr("^$Type: Expected even number of parameters, got 1");

        # Unknown parameter
        eval qq[\$a = new $Type  "anc", -Fred => 123 ;] ;
        like $@, mkEvalErr("^$Type: unknown key value\\(s\\) Fred");

        # no in or out param
        eval qq[\$a = new $Type ;] ;
        like $@, mkEvalErr("^$Type: Missing (Input|Output) parameter");

    }    


    {
        # write a very simple compressed file 
        # and read back 
        #========================================


        my $lex = new LexFile my $name ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        {
          my $x ;
          ok $x = new $CompressClass $name  ;

          ok $x->write($hello), "write" ;
          ok $x->flush(Z_FINISH), "flush";
          ok $x->close, "close" ;
        }

        {
          my $uncomp;
          ok my $x = new $UncompressClass $name, -Append => 1  ;

          my $len ;
          1 while ($len = $x->read($uncomp)) > 0 ;

          ok $x->close ;
          is $hello, $uncomp ;
        }
    }

    {
        # write a very simple compressed file 
        # and read back 
        #========================================


        my $name = "test.gz" ;
        my $lex = new LexFile $name ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        {
          my $x ;
          ok $x = new $CompressClass $name  ;

          is $x->write(''), 0, "Write empty string is ok";
          is $x->write(undef), 0, "Write undef is ok";
          ok $x->write($hello), "Write ok" ;
          ok $x->close, "Close ok" ;
        }

        {
          my $uncomp;
          my $x = new $UncompressClass $name  ;
          ok $x, "creates $UncompressClass $name"  ;

          my $data = '';
          $data .= $uncomp while $x->read($uncomp) > 0 ;

          ok $x->close, "close ok" ;
          is $data, $uncomp,"expected output" ;
        }
    }


    {
        # write a very simple file with using an IO filehandle
        # and read back 
        #========================================


        my $name = "test.gz" ;
        my $lex = new LexFile $name ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        {
          my $fh = new IO::File ">$name" ;
          ok $fh, "opened file $name ok";
          my $x = new $CompressClass $fh  ;
          ok $x, " created $CompressClass $fh"  ;

          is $x->fileno(), fileno($fh), "fileno match" ;
          is $x->write(''), 0, "Write empty string is ok";
          is $x->write(undef), 0, "Write undef is ok";
          ok $x->write($hello), "write ok" ;
          ok $x->flush(), "flush";
          ok $x->close,"close" ;
          $fh->close() ;
        }

        my $uncomp;
        {
          my $x ;
          ok my $fh1 = new IO::File "<$name" ;
          ok $x = new $UncompressClass $fh1, -Append => 1  ;
          ok $x->fileno() == fileno $fh1 ;

          1 while $x->read($uncomp) > 0 ;

          ok $x->close ;
        }

        ok $hello eq $uncomp ;
    }

    {
        # write a very simple file with using a glob filehandle
        # and read back 
        #========================================


        my $lex = new LexFile my $name ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        {
          title "$CompressClass: Input from typeglob filehandle";  
          ok open FH, ">$name" ;
 
          my $x = new $CompressClass *FH  ;
          ok $x, "  create $CompressClass"  ;

          is $x->fileno(), fileno(*FH), "  fileno" ;
          is $x->write(''), 0, "  Write empty string is ok";
          is $x->write(undef), 0, "  Write undef is ok";
          ok $x->write($hello), "  Write ok" ;
          ok $x->flush(), "  Flush";
          ok $x->close, "  Close" ;
          close FH;
        }

        my $uncomp;
        {
          title "$UncompressClass: Input from typeglob filehandle, append output";  
          my $x ;
          ok open FH, "<$name" ;
          ok $x = new $UncompressClass *FH, -Append => 1, Transparent => 0  ;
          is $x->fileno(), fileno FH, "  fileno ok" ;

          1 while $x->read($uncomp) > 0 ;

          ok $x->close, "  close" ;
        }

        is $uncomp, $hello, "  expected output" ;
    }

    {
        my $name = "test.gz" ;
        my $lex = new LexFile $name ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        {
          title "Outout to stdout via '-'" ;

          open(SAVEOUT, ">&STDOUT");
          my $dummy = fileno SAVEOUT;
          open STDOUT, ">$name" ;
 
          my $x = new $CompressClass '-'  ;
          $x->write($hello);
          $x->close;

          open(STDOUT, ">&SAVEOUT");

          ok 1, "  wrote to stdout" ;
        }

        {
          title "Input from stdin via filename '-'";  

          my $x ;
          my $uncomp ;
          my $stdinFileno = fileno(STDIN);
          # open below doesn't return 1 sometines on XP
             open(SAVEIN, "<&STDIN");
          ok open(STDIN, "<$name"), "  redirect STDIN";
          my $dummy = fileno SAVEIN;
          $x = new $UncompressClass '-';
          ok $x, "  created object" ;
          is $x->fileno(), $stdinFileno, "  fileno ok" ;

          1 while $x->read($uncomp) > 0 ;

          ok $x->close, "  close" ;
             open(STDIN, "<&SAVEIN");
          is $hello, $uncomp, "  expected output" ;
        }
    }

    {
        # write a compressed file to memory 
        # and read back 
        #========================================

        my $name = "test.gz" ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        my $buffer ;
        {
          my $x ;
          ok $x = new $CompressClass(\$buffer) ;
      
          ok ! defined $x->fileno() ;
          is $x->write(''), 0, "Write empty string is ok";
          is $x->write(undef), 0, "Write undef is ok";
          ok $x->write($hello) ;
          ok $x->flush();
          ok $x->close ;
      
          writeFile($name, $buffer) ;
          #is anyUncompress(\$buffer), $hello, "  any ok";
        }

        my $keep = $buffer ;
        my $uncomp;
        {
          my $x ;
          ok $x = new $UncompressClass(\$buffer, Append => 1)  ;

          ok ! defined $x->fileno() ;
          1 while $x->read($uncomp) > 0  ;

          ok $x->close ;
        }

        is $uncomp, $hello ;
        ok $buffer eq $keep ;
    }

    if ($CompressClass ne 'RawDeflate')
    {
        # write empty file
        #========================================

        my $buffer = '';
        {
          my $x ;
          ok $x = new $CompressClass(\$buffer) ;
          ok $x->close ;
      
        }

        my $keep = $buffer ;
        my $uncomp= '';
        {
          my $x ;
          ok $x = new $UncompressClass(\$buffer, Append => 1)  ;

          1 while $x->read($uncomp) > 0  ;

          ok $x->close ;
        }

        ok $uncomp eq '' ;
        ok $buffer eq $keep ;

    }

    {
        # write a larger file
        #========================================


        my $lex = new LexFile my $name ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        my $input    = '' ;
        my $contents = '' ;

        {
          my $x = new $CompressClass $name  ;
          ok $x, "  created $CompressClass object";

          ok $x->write($hello), "  write ok" ;
          $input .= $hello ;
          ok $x->write("another line"), "  write ok" ;
          $input .= "another line" ;
          # all characters
          foreach (0 .. 255)
            { $contents .= chr int $_ }
          # generate a long random string
          foreach (1 .. 5000)
            { $contents .= chr int rand 256 }

          ok $x->write($contents), "  write ok" ;
          $input .= $contents ;
          ok $x->close, "  close ok" ;
        }

        ok myGZreadFile($name) eq $input ;
        my $x =  readFile($name) ;
        #print "length " . length($x) . " \n";
    }

    {
        # embed a compressed file in another file
        #================================


        my $name = "test.gz" ;
        my $lex = new LexFile $name ;

        my $hello = <<EOM ;
hello world
this is a test
EOM

        my $header = "header info\n" ;
        my $trailer = "trailer data\n" ;

        {
          my $fh ;
          ok $fh = new IO::File ">$name" ;
          print $fh $header ;
          my $x ;
          ok $x = new $CompressClass $fh,
                                     -AutoClose => 0   ;

          ok $x->binmode();
          ok $x->write($hello) ;
          ok $x->close ;
          print $fh $trailer ;
          $fh->close() ;
        }

        my ($fil, $uncomp) ;
        my $fh1 ;
        ok $fh1 = new IO::File "<$name" ;
        # skip leading junk
        my $line = <$fh1> ;
        ok $line eq $header ;

        ok my $x = new $UncompressClass $fh1  ;
        ok $x->binmode();
        my $got = $x->read($uncomp);

        ok $uncomp eq $hello ;
        my $rest ;
        read($fh1, $rest, 5000);
        is ${ $x->trailingData() } . $rest, $trailer ;
        #print ${ $x->trailingData() } . $rest ;

    }

    {
        # Write
        # these tests come almost 100% from IO::String

        my $name = "test.gz" ;
        my $lex = new LexFile $name ;

        my $io = $CompressClass->new($name);

        is $io->tell(), 0, " tell returns 0"; ;

        my $heisan = "Heisan\n";
        $io->print($heisan) ;

        ok ! $io->eof(), "  ! eof";

        is $io->tell(), length($heisan), "  tell is " . length($heisan) ;

        $io->print("a", "b", "c");

        {
            local($\) = "\n";
            $io->print("d", "e");
            local($,) = ",";
            $io->print("f", "g", "h");
        }

        {
            local($\) ;
            $io->print("D", "E");
            local($,) = ".";
            $io->print("F", "G", "H");
        }

        my $foo = "1234567890";
        
        is $io->syswrite($foo, length($foo)), length($foo), "  syswrite ok" ;
        if ( $[ < 5.6 )
          { is $io->syswrite($foo, length $foo), length $foo, "  syswrite ok" }
        else
          { is $io->syswrite($foo), length $foo, "  syswrite ok" }
        is $io->syswrite($foo, length($foo)), length $foo, "  syswrite ok";
        is $io->write($foo, length($foo), 5), 5,   " write 5";
        is $io->write("xxx\n", 100, -1), 1, "  write 1";

        for (1..3) {
            $io->printf("i(%d)", $_);
            $io->printf("[%d]\n", $_);
        }
        $io->print("\n");

        $io->close ;

        ok $io->eof(), "  eof";

        is myGZreadFile($name), "Heisan\nabcde\nf,g,h\nDEF.G.H" .
                                ("1234567890" x 3) . "67890\n" .
                                    "i(1)[1]\ni(2)[2]\ni(3)[3]\n\n";


    }

    {
        # Read
        my $str = <<EOT;
This is an example
of a paragraph


and a single line.

EOT

        my $name = "test.gz" ;
        my $lex = new LexFile $name ;

        my %opts = () ;
        %opts = (CRC32 => 1, Adler32 => 1)
            if $CompressClass ne "IO::Compress::Gzip";
        my $iow = new $CompressClass $name, %opts;
        $iow->print($str) ;
        $iow->close ;

        my @tmp;
        my $buf;
        {
            my $io = new $UncompressClass $name ;
        
            ok ! $io->eof;
            is $io->tell(), 0 ;
            #my @lines = <$io>;
            my @lines = $io->getlines();
            is @lines, 6
                or print "# Got " . scalar(@lines) . " lines, expected 6\n" ;
            is $lines[1], "of a paragraph\n" ;
            is join('', @lines), $str ;
            is $., 6; 
            is $io->tell(), length($str) ;
        
            ok $io->eof;

            ok ! ( defined($io->getline)  ||
                      (@tmp = $io->getlines) ||
                      defined($io->getline)         ||
                      defined($io->getc)     ||
                      $io->read($buf, 100)   != 0) ;
        }
        
        
        {
            local $/;  # slurp mode
            my $io = $UncompressClass->new($name);
            ok ! $io->eof;
            my @lines = $io->getlines;
            ok $io->eof;
            ok @lines == 1 && $lines[0] eq $str;
        
            $io = $UncompressClass->new($name);
            ok ! $io->eof;
            my $line = $io->getline();
            ok $line eq $str;
            ok $io->eof;
        }
        
        {
            local $/ = "";  # paragraph mode
            my $io = $UncompressClass->new($name);
            ok ! $io->eof;
            my @lines = $io->getlines();
            ok $io->eof;
            ok @lines == 2 
                or print "# Got " . scalar(@lines) . " lines, expected 2\n" ;
            ok $lines[0] eq "This is an example\nof a paragraph\n\n\n"
                or print "# $lines[0]\n";
            ok $lines[1] eq "and a single line.\n\n";
        }
        
        {
            local $/ = "is";
            my $io = $UncompressClass->new($name);
            my @lines = ();
            my $no = 0;
            my $err = 0;
            ok ! $io->eof;
            while (my $a = $io->getline()) {
                push(@lines, $a);
                $err++ if $. != ++$no;
            }
        
            ok $err == 0 ;
            ok $io->eof;
        
            ok @lines == 3 
                or print "# Got " . scalar(@lines) . " lines, expected 3\n" ;
            ok join("-", @lines) eq
                             "This- is- an example\n" .
                            "of a paragraph\n\n\n" .
                            "and a single line.\n\n";
        }
        
        
        # Test read
        
        {
            my $io = $UncompressClass->new($name);
        

            eval { $io->read(1) } ;
            like $@, mkErr("buffer parameter is read-only");

            is $io->read($buf, 0), 0, "Requested 0 bytes" ;

            ok $io->read($buf, 3) == 3 ;
            ok $buf eq "Thi";
        
            ok $io->sysread($buf, 3, 2) == 3 ;
            ok $buf eq "Ths i"
                or print "# [$buf]\n" ;;
            ok ! $io->eof;
        
    #        $io->seek(-4, 2);
    #    
    #        ok ! $io->eof;
    #    
    #        ok read($io, $buf, 20) == 4 ;
    #        ok $buf eq "e.\n\n";
    #    
    #        ok read($io, $buf, 20) == 0 ;
    #        ok $buf eq "";
    #   
    #        ok ! $io->eof;
        }

    }

    {
        # Read from non-compressed file

        my $str = <<EOT;
This is an example
of a paragraph


and a single line.

EOT

        my $name = "test.gz" ;
        my $lex = new LexFile $name ;

        writeFile($name, $str);
        my @tmp;
        my $buf;
        {
            my $io = new $UncompressClass $name, -Transparent => 1 ;
        
            ok defined $io;
            ok ! $io->eof;
            ok $io->tell() == 0 ;
            my @lines = $io->getlines();
            ok @lines == 6; 
            ok $lines[1] eq "of a paragraph\n" ;
            ok join('', @lines) eq $str ;
            ok $. == 6; 
            ok $io->tell() == length($str) ;
        
            ok $io->eof;

            ok ! ( defined($io->getline)  ||
                      (@tmp = $io->getlines) ||
                      defined($io->getline)         ||
                      defined($io->getc)     ||
                      $io->read($buf, 100)   != 0) ;
        }
        
        
        {
            local $/;  # slurp mode
            my $io = $UncompressClass->new($name);
            ok ! $io->eof;
            my @lines = $io->getlines;
            ok $io->eof;
            ok @lines == 1 && $lines[0] eq $str;
        
            $io = $UncompressClass->new($name);
            ok ! $io->eof;
            my $line = $io->getline;
            ok $line eq $str;
            ok $io->eof;
        }
        
        {
            local $/ = "";  # paragraph mode
            my $io = $UncompressClass->new($name);
            ok ! $io->eof;
            my @lines = $io->getlines;
            ok $io->eof;
            ok @lines == 2 
                or print "# exected 2 lines, got " . scalar(@lines) . "\n";
            ok $lines[0] eq "This is an example\nof a paragraph\n\n\n"
                or print "# [$lines[0]]\n" ;
            ok $lines[1] eq "and a single line.\n\n";
        }
        
        {
            local $/ = "is";
            my $io = $UncompressClass->new($name);
            my @lines = ();
            my $no = 0;
            my $err = 0;
            ok ! $io->eof;
            while (my $a = $io->getline) {
                push(@lines, $a);
                $err++ if $. != ++$no;
            }
        
            ok $err == 0 ;
            ok $io->eof;
        
            ok @lines == 3 ;
            ok join("-", @lines) eq
                             "This- is- an example\n" .
                            "of a paragraph\n\n\n" .
                            "and a single line.\n\n";
        }
        
        
        # Test read
        
        {
            my $io = $UncompressClass->new($name);
        
            ok $io->read($buf, 3) == 3 ;
            ok $buf eq "Thi";
        
            ok $io->sysread($buf, 3, 2) == 3 ;
            ok $buf eq "Ths i";
            ok ! $io->eof;
        
    #        $io->seek(-4, 2);
    #    
    #        ok ! $io->eof;
    #    
    #        ok read($io, $buf, 20) == 4 ;
    #        ok $buf eq "e.\n\n";
    #    
    #        ok read($io, $buf, 20) == 0 ;
    #        ok $buf eq "";
    #    
    #        ok ! $io->eof;
        }


    }

    {
        # Vary the length parameter in a read

        my $str = <<EOT;
x
x
This is an example
of a paragraph


and a single line.

EOT
        $str = $str x 100 ;


        foreach my $bufsize (1, 3, 512, 4096, length($str)-1, length($str), length($str)+1)
        {
            foreach my $trans (0, 1)
            {
                foreach my $append (0, 1)
                {
                    title "Read Tests - buf length $bufsize, Transparent $trans, Append $append" ;

                    my $name = "testz.gz" ;
                    my $lex = new LexFile $name ;

                    if ($trans) {
                        writeFile($name, $str) ;
                    }
                    else {
                        my $iow = new $CompressClass $name;
                        $iow->print($str) ;
                        $iow->close ;
                    }

                    
                    my $io = $UncompressClass->new($name, 
                                                   -Append => $append,
                                                   -Transparent  => $trans);
                
                    my $buf;
                    
                    is $io->tell(), 0;

                    if ($append) {
                        1 while $io->read($buf, $bufsize) > 0;
                    }
                    else {
                        my $tmp ;
                        $buf .= $tmp while $io->read($tmp, $bufsize) > 0 ;
                    }
                    is length $buf, length $str;
                    ok $buf eq $str ;
                    ok ! $io->error() ;
                    ok $io->eof;
                }
            }
        }
    }

    foreach my $file (0, 1)
    {
        foreach my $trans (0, 1)
        {
            title "seek tests - file $file trans $trans" ;

            my $buffer ;
            my $buff ;
            my $name = "test.gz" ;
            my $lex = new LexFile $name ;

            my $first = "beginning" ;
            my $last  = "the end" ;

            if ($trans)
            {
                $buffer = $first . "\x00" x 10 . $last;
                writeFile($name, $buffer);
            }
            else
            {
                my $output ;
                if ($file)
                {
                    $output = $name ;
                }
                else
                {
                    $output = \$buffer;
                }

                my $iow = new $CompressClass $output ;
                $iow->print($first) ;
                ok $iow->seek(5, SEEK_CUR) ;
                ok $iow->tell() == length($first)+5;
                ok $iow->seek(0, SEEK_CUR) ;
                ok $iow->tell() == length($first)+5;
                ok $iow->seek(length($first)+10, SEEK_SET) ;
                ok $iow->tell() == length($first)+10;

                $iow->print($last) ;
                $iow->close ;
            }

            my $input ;
            if ($file)
            {
                $input = $name ;
            }
            else
            {
                $input = \$buffer ;
            }

            ok myGZreadFile($input) eq $first . "\x00" x 10 . $last ;

            my $io = $UncompressClass->new($input, Strict => 1);
            ok $io->seek(length($first), SEEK_CUR) ;
            ok ! $io->eof;
            is $io->tell(), length($first);

            ok $io->read($buff, 5) ;
            is $buff, "\x00" x 5 ;
            is $io->tell(), length($first) + 5;

            ok $io->seek(0, SEEK_CUR) ;
            my $here = $io->tell() ;
            is $here, length($first)+5;

            ok $io->seek($here+5, SEEK_SET) ;
            is $io->tell(), $here+5 ;
            ok $io->read($buff, 100) ;
            ok $buff eq $last ;
            ok $io->eof;
        }
    }

    {
        title "seek error cases" ;

        my $b ;
        my $a = new $CompressClass(\$b)  ;

        ok ! $a->error() ;
        eval { $a->seek(-1, 10) ; };
        like $@, mkErr("^${CompressClass}::seek: unknown value, 10, for whence parameter");

        eval { $a->seek(-1, SEEK_END) ; };
        like $@, mkErr("^${CompressClass}::seek: cannot seek backwards");

        $a->write("fred");
        $a->close ;


        my $u = new $UncompressClass(\$b)  ;

        eval { $u->seek(-1, 10) ; };
        like $@, mkErr("^${UncompressClass}::seek: unknown value, 10, for whence parameter");

        eval { $u->seek(-1, SEEK_END) ; };
        like $@, mkErr("^${UncompressClass}::seek: SEEK_END not allowed");

        eval { $u->seek(-1, SEEK_CUR) ; };
        like $@, mkErr("^${UncompressClass}::seek: cannot seek backwards");
    }
    
    foreach my $fb (qw(filename buffer filehandle))
    {
        foreach my $append (0, 1)
        {
            {
                title "$CompressClass -- Append $append, Output to $fb" ;

                my $name = "test.gz" ;
                my $lex = new LexFile $name ;

                my $already = 'already';
                my $buffer = $already;
                my $output;

                if ($fb eq 'buffer')
                  { $output = \$buffer }
                elsif ($fb eq 'filename')
                {
                    $output = $name ;
                    writeFile($name, $buffer);
                }
                elsif ($fb eq 'filehandle')
                {
                    $output = new IO::File ">$name" ;
                    print $output $buffer;
                }

                my $a = new $CompressClass($output, Append => $append)  ;
                ok $a, "  Created $CompressClass";
                my $string = "appended";
                $a->write($string);
                $a->close ;

                my $data ; 
                if ($fb eq 'buffer')
                {
                    $data = $buffer;
                }
                else
                {
                    $output->close
                        if $fb eq 'filehandle';
                    $data = readFile($name);
                }

                if ($append || $fb eq 'filehandle')
                {
                    is substr($data, 0, length($already)), $already, "  got prefix";
                    substr($data, 0, length($already)) = '';
                }


                my $uncomp;
                my $x = new $UncompressClass(\$data, Append => 1)  ;
                ok $x, "  created $UncompressClass";

                my $len ;
                1 while ($len = $x->read($uncomp)) > 0 ;

                $x->close ;
                is $uncomp, $string, '  Got uncompressed data' ;
                
            }
        }
    }

    foreach my $type (qw(buffer filename filehandle))
    {
        title "$UncompressClass -- InputLength, read from $type";

        my $compressed ; 
        my $string = "some data";
        my $c = new $CompressClass(\$compressed);
        $c->write($string);
        $c->close();

        my $appended = "append";
        my $comp_len = length $compressed;
        $compressed .= $appended;

        my $name = "test.gz" ;
        my $lex = new LexFile $name ;
        my $input ;
        writeFile ($name, $compressed);

        if ($type eq 'buffer')
        {
            $input = \$compressed;
        }
        if ($type eq 'filename')
        {
            $input = $name;
        }
        elsif ($type eq 'filehandle')
        {
            my $fh = new IO::File "<$name" ;
            ok $fh, "opened file $name ok";
            $input = $fh ;
        }

        my $x = new $UncompressClass($input, InputLength => $comp_len)  ;
        ok $x, "  created $UncompressClass";

        my $len ;
        my $output;
        $len = $x->read($output, 100);
        is $len, length($string);
        is $output, $string;

        if ($type eq 'filehandle')
        {
            my $rest ;
            $input->read($rest, 1000);
            is $rest, $appended;
        }


    }
    
    foreach my $append (0, 1)
    {
        title "$UncompressClass -- Append $append" ;

        my $name = "test.gz" ;
        my $lex = new LexFile $name ;

        my $string = "appended";
        my $compressed ; 
        my $c = new $CompressClass(\$compressed);
        $c->write($string);
        $c->close();

        my $x = new $UncompressClass(\$compressed, Append => $append)  ;
        ok $x, "  created $UncompressClass";

        my $already = 'already';
        my $output = $already;

        my $len ;
        $len = $x->read($output, 100);
        is $len, length($string);

        $x->close ;

        if ($append)
        {
            is substr($output, 0, length($already)), $already, "  got prefix";
            substr($output, 0, length($already)) = '';
        }
        is $output, $string, '  Got uncompressed data' ;
    }
    

    foreach my $file (0, 1)
    {
        foreach my $trans (0, 1)
        {
            title "ungetc, File $file, Transparent $trans" ;

            my $name = "test.gz" ;
            my $lex = new LexFile $name ;

            my $string = 'abcdeABCDE';
            my $b ;
            if ($trans)
            {
                $b = $string ;
            }
            else
            {
                my $a = new $CompressClass(\$b)  ;
                $a->write($string);
                $a->close ;
            }

            my $from ;
            if ($file)
            {
                writeFile($name, $b);
                $from = $name ;
            }
            else
            {
                $from = \$b ;
            }

            my $u = $UncompressClass->new($from, Transparent => 1)  ;
            my $first;
            my $buff ;

            # do an ungetc before reading
            $u->ungetc("X");
            $first = $u->getc();
            is $first, 'X';

            $first = $u->getc();
            is $first, substr($string, 0,1);
            $u->ungetc($first);
            $first = $u->getc();
            is $first, substr($string, 0,1);
            $u->ungetc($first);

            is $u->read($buff, 5), 5 ;
            is $buff, substr($string, 0, 5);

            $u->ungetc($buff) ;
            is $u->read($buff, length($string)), length($string) ;
            is $buff, $string;

            ok $u->eof() ;

            my $extra = 'extra';
            $u->ungetc($extra);
            ok ! $u->eof();
            is $u->read($buff), length($extra) ;
            is $buff, $extra;
            
            ok $u->eof() ;

            $u->close();

        }
    }

    {
        title "inflateSync on plain file";

        my $hello = "I am a HAL 9000 computer" x 2001 ;

        my ($k, $err) = new $UncompressClass(\$hello, Transparent => 1);
        ok $k ;
        cmp_ok $err, '==', Z_OK ;
     
        # Skip to the flush point -- no-op for plain file
        my $status = $k->inflateSync();
        is $status, 1 
            or diag $k->error() ;
     
        my $rest; 
        is $k->read($rest, length($hello)), length($hello)
            or diag $k->error() ;
        ok $rest eq $hello ;

        ok $k->close();
    }

    {
        title "inflateSync for real";

        # create a deflate stream with flush points

        my $hello = "I am a HAL 9000 computer" x 2001 ;
        my $goodbye = "Will I dream?" x 2010;
        my ($x, $err, $answer, $X, $Z, $status);
        my $Answer ;
     
        ok ($x = new $CompressClass(\$Answer));
        ok $x ;
     
        is $x->write($hello), length($hello);
    
        # create a flush point
        ok $x->flush(Z_FULL_FLUSH) ;
         
        is $x->write($goodbye), length($goodbye);
    
        ok $x->close() ;
     
        my $k;
        ($k, $err) = new $UncompressClass(\$Answer, BlockSize => 1);
        ok $k ;
        cmp_ok $err, '==', Z_OK ;
     
        my $initial;
        is $k->read($initial, 1), 1 ;
        is $initial, substr($hello, 0, 1);

        # Skip to the flush point
        $status = $k->inflateSync();
        is $status, 1 
            or diag $k->error() ;
     
        my $rest; 
        is $k->read($rest, length($hello) + length($goodbye)), 
                length($goodbye)
            or diag $k->error() ;
        ok $rest eq $goodbye ;

        ok $k->close();
    }

    {
        title "inflateSync no FLUSH point";

        # create a deflate stream with flush points

        my $hello = "I am a HAL 9000 computer" x 2001 ;
        my ($x, $err, $answer, $X, $Z, $status);
        my $Answer ;
     
        ok ($x = new $CompressClass(\$Answer));
        ok $x ;
     
        is $x->write($hello), length($hello);
    
        ok $x->close() ;
     
        my $k;
        ($k, $err) = new $UncompressClass(\$Answer, BlockSize => 1);
        ok $k ;
        cmp_ok $err, '==', Z_OK ;
     
        my $initial;
        is $k->read($initial, 1), 1 ;
        is $initial, substr($hello, 0, 1);

        # Skip to the flush point
        $status = $k->inflateSync();
        is $status, 0 
            or diag $k->error() ;
     
        ok $k->close();
        is $k->inflateSync(), 0 ;
    }

    {
        title "write tests - invalid data" ;

        #my $name1 = "test.gz" ;
        #my $lex = new LexFile $name1 ;
        my $Answer ;

        #ok ! -e $name1, "  File $name1 does not exist";

        my @data = (
            [ '{ }',         "${CompressClass}::write: input parameter not a filename, filehandle, array ref or scalar ref" ], 
            [ '[ { } ]',     "${CompressClass}::write: input parameter not a filename, filehandle, array ref or scalar ref" ], 
            [ '[ [ { } ] ]', "${CompressClass}::write: input parameter not a filename, filehandle, array ref or scalar ref" ], 
            [ '[ "" ]',      "${CompressClass}::write: input filename is undef or null string" ], 
            [ '[ undef ]',   "${CompressClass}::write: input filename is undef or null string" ], 
            [ '[ \$Answer ]',"${CompressClass}::write: input and output buffer are identical" ], 
            #[ "not readable", 'xx' ], 
            # same filehandle twice, 'xx'
           ) ;

        foreach my $data (@data)
        {
            my ($send, $get) = @$data ;
            title "${CompressClass}::write( $send )";
            my $copy;
            eval "\$copy = $send";
            my $x = new $CompressClass(\$Answer);
            ok $x, "  Created $CompressClass object";
            eval { $x->write($copy) } ;
            #like $@, "/^$get/", "  error - $get";
            like $@, "/not a scalar reference /", "  error - not a scalar reference";
        }

#        @data = (
#            [ '[ $name1 ]',  "input file '$name1' does not exist" ], 
#            #[ "not readable", 'xx' ], 
#            # same filehandle twice, 'xx'
#           ) ;
#
#        foreach my $data (@data)
#        {
#            my ($send, $get) = @$data ;
#            title "${CompressClass}::write( $send )";
#            my $copy;
#            eval "\$copy = $send";
#            my $x = new $CompressClass(\$Answer);
#            ok $x, "  Created $CompressClass object";
#            ok ! $x->write($copy), "  write fails"  ;
#            like $$Error, "/^$get/", "  error - $get";
#        }

        #exit;
        
    }


#    sub deepCopy
#    {
#        if (! ref $_[0] || ref $_[0] eq 'SCALAR')
#        {
#            return $_[0] ;
#        }
#
#        if (ref $_[0] eq 'ARRAY')
#        {
#            my @a ;
#            for my $x ( @{ $_[0] })
#            {
#                push @a, deepCopy($x);
#            }
#
#            return \@a ;
#        }
#
#        croak "bad! $_[0]";
#
#    }
#
#    sub deepSubst
#    {
#        #my $data = shift ;
#        my $from = $_[1] ;
#        my $to   = $_[2] ;
#
#        if (! ref $_[0])
#        {
#            $_[0] = $to 
#                if $_[0] eq $from ;
#            return ;    
#
#        }
#
#        if (ref $_[0] eq 'SCALAR')
#        {
#            $_[0] = \$to 
#                if defined ${ $_[0] } && ${ $_[0] } eq $from ;
#            return ;    
#
#        }
#
#        if (ref $_[0] eq 'ARRAY')
#        {
#            for my $x ( @{ $_[0] })
#            {
#                deepSubst($x, $from, $to);
#            }
#            return ;
#        }
#        #croak "bad! $_[0]";
#    }

#    {
#        title "More write tests" ;
#
#        my $file1 = "file1" ;
#        my $file2 = "file2" ;
#        my $file3 = "file3" ;
#        my $lex = new LexFile $file1, $file2, $file3 ;
#
#        writeFile($file1, "F1");
#        writeFile($file2, "F2");
#        writeFile($file3, "F3");
#
#        my @data = (
#              [ '""',                                   ""      ],
#              [ 'undef',                                ""      ],
#              [ '"abcd"',                               "abcd"  ],
#
#              [ '\""',                                   ""     ],
#              [ '\undef',                                ""     ],
#              [ '\"abcd"',                               "abcd" ],
#
#              [ '[]',                                    ""     ],
#              [ '[[]]',                                  ""     ],
#              [ '[[[]]]',                                ""     ],
#              [ '[\""]',                                 ""     ],
#              [ '[\undef]',                              ""     ],
#              [ '[\"abcd"]',                             "abcd" ],
#              [ '[\"ab", \"cd"]',                        "abcd" ],
#              [ '[[\"ab"], [\"cd"]]',                    "abcd" ],
#
#              [ '$file1',                                $file1 ],
#              [ '$fh2',                                  "F2"   ],
#              [ '[$file1, \"abc"]',                      "F1abc"],
#              [ '[\"a", $file1, \"bc"]',                 "aF1bc"],
#              [ '[\"a", $fh1, \"bc"]',                   "aF1bc"],
#              [ '[\"a", $fh1, \"bc", $file2]',           "aF1bcF2"],
#              [ '[\"a", $fh1, \"bc", $file2, $fh3]',     "aF1bcF2F3"],
#            ) ;
#
#
#        foreach my $data (@data)
#        {
#            my ($send, $get) = @$data ;
#
#            my $fh1 = new IO::File "< $file1" ;
#            my $fh2 = new IO::File "< $file2" ;
#            my $fh3 = new IO::File "< $file3" ;
#
#            title "${CompressClass}::write( $send )";
#            my $copy;
#            eval "\$copy = $send";
#            my $Answer ;
#            my $x = new $CompressClass(\$Answer);
#            ok $x, "  Created $CompressClass object";
#            my $len = length $get;
#            is $x->write($copy), length($get), "  write $len bytes";
#            ok $x->close(), "  close ok" ;
#
#            is myGZreadFile(\$Answer), $get, "  got expected output" ;
#            cmp_ok $$Error, '==', 0, "  no error";
#
#
#        }
#        
#    }
}






