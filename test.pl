# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#use Test;

use constant USERID	=> "GnuPG Test";
use constant PASSWD	=> "test";
use constant UNTRUSTED	=> "Francis";
BEGIN {
    $| = 1;
}

use GnuPG;

my $gpg = new GnuPG( homedir => "test", trace => 0 );

sub gen_key_test {
    print "Key generation => ";
    $gpg->gen_key(
		  passphrase => PASSWD,
		  name	     => USERID,
		 );
}

sub import_test {
    print "Import new public key => ";
    $gpg->import_keys( keys => "test/key1.pub" );
}

sub import2_test {
    print "Import existing public key => ";
    $gpg->import_keys( keys => "test/key1.pub" );
}

sub import3_test {
    print "Import many public keys => ";
    $gpg->import_keys( keys => [ qw( test/key1.pub test/key2.pub ) ] );
}
sub export_test {
    print "Public key export => ";
    $gpg->export_keys( keys	=> USERID,
		       armor	=> 1,
		       output	=> "test/key.pub",
		     );
}

sub export2_test {
    print "Exporting public key ring => ";
    $gpg->export_keys( armor	=> 1,
		       output	=> "test/keyring.pub",
		     );
}

sub export_secret_test {
    print "Exporting secret key => ";
    $gpg->export_keys( secret	=> 1,
		       armor	=> 1,
		       output	=> "test/key.sec",
		     );
}

sub encrypt_test {
    print "Encrypt => ";
    $gpg->encrypt(
		  recipient => USERID,
		  output    => "test/file.txt.gpg",
		  armor	    => 1,
		  plaintext => "test/file.txt",
		 );
}

sub encrypt_sign_test {
    print "Encrypt and Sign => ";
    $gpg->encrypt(
		  recipient	=> USERID,
		  output	=> "test/file.txt.sgpg",
		  armor		=> 1,
		  sign		=> 1,
		  plaintext	=> "test/file.txt",
		  passphrase	=> PASSWD,
		 );
}

sub encrypt_sym_test {
    print "Symmetric encryption => ";
    $gpg->encrypt(
		  output	=> "test/file.txt.cipher",
		  armor		=> 1,
		  plaintext	=> "test/file.txt",
		  symmetric	=> 1,
		  passphrase	=> PASSWD,
		 );
}

sub encrypt_notrust_test {
    print "Encrypt to undefined trust => ";
    $gpg->encrypt(
		  recipient	=> UNTRUSTED,
		  output	=> "test/file.txt.dist.gpg",
		  armor		=> 1,
		  sign		=> 1,
		  plaintext	=> "test/file.txt",
		  passphrase	=> PASSWD,
		 );
}

sub sign_test {
    print "Sign a file => ";
    $gpg->sign(
		  recipient	=> USERID,
		  output	=> "test/file.txt.sig",
		  armor		=> 1,
		  plaintext	=> "test/file.txt",
		  passphrase	=> PASSWD,
		 );
}

sub detachsign_test {
    print "Detach signature of a file => ";
    $gpg->sign(
		  recipient	=> USERID,
		  output	=> "test/file.txt.asc",
		  "detach-sign" => 1,
		  armor		=> 1,
		  plaintext	=> "test/file.txt",
		  passphrase	=> PASSWD,
		 );
}

sub clearsign_test {
    print "Clear Sign a File => ";
    $gpg->clearsign(
		    output	=> "test/file.txt.clear",
		    armor	=> 1,
		    plaintext	=> "test/file.txt",
		    passphrase  => PASSWD,
		 );
}

sub decrypt_test {
    print "Decrypt a file => ";
    $gpg->decrypt(
		    output	=> "test/file.txt.plain",
		    ciphertext	=> "test/file.txt.gpg",
		    passphrase  => PASSWD,
		 );
}

sub decrypt_sign_test {
    print "Clear Sign a File => ";
    $gpg->decrypt(
		    output	=> "test/file.txt.plain2",
		    ciphertext	=> "test/file.txt.sgpg",
		    passphrase  => PASSWD,
		 );
}

sub decrypt_sym_test {
    print "Symmetric decryption => ";
    $gpg->decrypt(
		    output	=> "test/file.txt.plain3",
		    ciphertext	=> "test/file.txt.cipher",
		    symmetric	=> 1,
		    passphrase  => PASSWD,
		 );
}

sub verify_sign_test {
    print "Verify a signed file => ";
    $gpg->verify( signature	=> "test/file.txt.sig" );
}

sub verify_detachsign_test {
    print "Verify a detach signature => ";
    $gpg->verify( signature	=> "test/file.txt.asc",
		  file		=> "test/file.txt",
		);
}

sub verify_clearsign_test {
    print "Verify a clearsigned file => ";
    $gpg->verify( signature => "test/file.txt.clear" );
}

sub encrypt_from_fh_test {
    print "Encrypt from file handle => ";
    open ( FH, "test/file.txt" )
      or die "error opening file: $!\n";
    $gpg->encrypt(
		  recipient => UNTRUSTED,
		  output    => "test/file-fh.txt.gpg",
		  armor	    => 1,
		  plaintext => \*FH,
		 );
    close ( FH )
      or die "error closing file: $!\n";
}

sub encrypt_to_fh_test {
    print "Encrypt to file handle => ";
    open ( FH, ">test/file-fho.txt.gpg" )
      or die "error opening file: $!\n";
    $gpg->encrypt(
		  recipient => UNTRUSTED,
		  output    => \*FH,
		  armor	    => 1,
		  plaintext => "test/file.txt",
		 );
    close ( FH )
      or die "error closing file: $!\n";
}

my @tests = qw( gen_key_test
    		import_test	 import2_test		import3_test
    		export_test	 export2_test		export_secret_test
    		encrypt_test	 encrypt_sign_test	encrypt_sym_test
    		encrypt_notrust_test
    		decrypt_test	 decrypt_sign_test	decrypt_sym_test
    		sign_test	 detachsign_test	clearsign_test
    		verify_sign_test verify_detachsign_test verify_clearsign_test
    	        );
print "1..", scalar @tests, "\n";
my $i = 1;
for ( @tests ) {
    eval { 
	no strict 'refs';   # We are using symbolic references
	&$_();
    };
    if ( $@ ) {
	print "not ok $i: $@";
    } else {
	print "ok $i\n";
    }
    $i++;
}



