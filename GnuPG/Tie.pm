#
#    GnuPG.pm - Abstract tied interface to the GnuPG.
#
#    This file is part of GnuPG.pm.
#
#    Author: Francis J. Lacoste <francis.lacoste@iNsu.COM>
#
#    Copyright (C) 1999 Francis J. Lacoste, iNsu Innovations
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
package GnuPG::Tie;

use GnuPG;
use Symbol;

use Carp;

use Fcntl;

use strict;

sub TIEHANDLE {
    my $class = shift;
    $class = ref $class || $class;

    my ($child_in, $child_out)	= ( gensym, gensym );
    my ($parent_in,$parent_out) = ( gensym, gensym );
    pipe $child_in, $parent_out
      or croak "error while creating pipe: $!";
    pipe $parent_in, $child_out
      or croak "error while creating pipe: $!";

    # Unbuffer writer pipes
    for my $fd ( ($child_out, $parent_out) ) {
	my $old = select $fd; 
	$| = 1; 
	select $old;
    }

    # Keep pipes open after exec
    # Removed close on exec from all file descriptor
    for my $fd ( ( $child_in, $child_out, $parent_in, $parent_out ) ) {
	fcntl( $fd, F_SETFD, 0 )
	  or croak "error removing close on exec flag: $!\n" ;
    }

    my $child = fork;
    croak "error in fork: $!" unless defined $child;
    if ( $child ) {
	# Those aren't use in the parent
	close $child_in;
	close $child_out;

	# Operate in non blocking mode
	for my $fd ( $parent_in, $parent_out ) {
	    my $flags = fcntl $fd, F_GETFL, 0
	      or croak "error getting flags on pipe: $!\n";
	    fcntl $fd, F_SETFL, $flags | O_NONBLOCK
	      or croak "error setting non-blocking IO on pipe: $!\n";
	}

	return bless { reader	    => $parent_in,
		       writer	    => $parent_out,
		       done_writing => 0,
		       buffer	    => "",
		       len	    => 0,
		       offset	    => 0,
		       child	    => $child,
		       line_buffer  => "",
		       eof	    => 0,
		     }, $class;
    } else {
	# Those aren't use in the child
	close $parent_in;
	close $parent_out;

	# Redirect stdin and stdout to our pipe
	open ( STDIN, "<&" . fileno $child_in )
	  or croak "can't redirect stdin to pipe: $!\n";
	open ( STDOUT, ">&" . fileno $child_out )
	  or croak "can't redirect stdout to pipe: $!\n";

	# Let subclass call the appropriate method and set
	# up the GnuPG object.
	$class->run_gnupg( @_ );

	close $child_in;
	close $child_out;

	# This is needed because mod_perl override this
	CORE::exit( 0 );
    }
}

sub WRITE {
    my ( $self, $buf, $len, $offset ) = @_;

    croak "attempt to read on a closed file handle\n"
      unless defined $self->{writer};

    croak ( "can't write after having read" ) if $self->{done_writing};

    my ( $r_in, $w_in ) = ( '', '' );
    vec( $r_in, fileno $self->{reader}, 1) = 1;
    vec( $w_in, fileno $self->{writer}, 1) = 1;

    my $left = $len;
    while ( $left ) {
	my ($r_out, $w_out) = ($r_in, $w_in);
	my $nfound = select $r_out, $w_out, undef, undef;
	croak "error in select: $!\n" unless defined $nfound;

	# Check if we can write
	if ( vec $w_out, fileno $self->{writer}, 1 ) {
	    my $n = syswrite $self->{writer}, $buf, $len, $offset;
	    croak "error on write: $!\n" unless defined $n;
	    $left -= $n;
	    $offset += $n;
	}
	# Check if we can read
	if ( vec $r_out, fileno $self->{reader}, 1 ) {
	    my $n = sysread $self->{reader}, $self->{buffer}, 1024,
	      $self->{len};
	    croak "error on read: $!\n" unless defined $n;
	    $self->{len} += $n;
	}
    }

    return $len;
}

sub done_writing() {
    my $self = shift;

    # Once we start reading, no other writing can be place
    # on the pipe. So we close the writer file descriptor
    unless ( $self->{done_writing} ) {
	$self->{done_writing} = 1;
	close $self->{writer}
	  or croak "error closing writer pipe: $\n";
    }
}

sub READ {
    my $self = shift;
    my $bufref = \$_[0];
    my ( undef, $len, $offset ) = @_;

    croak "attempt to read on a closed file handle\n" 
      unless defined $self->{reader};

    if ( $self->{eof}) {
	$self->{eof} = 0;
	return 0;
    }

    # Start reading the input
    $self->done_writing unless ( $self->{done_writing} );

    # Check if we have something in our buffer
    if ( $self->{len} - $self->{offset} ) {
	my $left = $self->{len} - $self->{offset};
	my $n = $left > $len ? $len : $left;
	substr( $$bufref, $offset, $len) =
	  substr $self->{buffer}, $self->{offset}, $n;
	$self->{offset} += $n;

	# Return only if we have read the requested length.
	return $n if $n == $len;

	$offset += $n;
	$len    -= $n;
    }

    # Wait for the reader fd to come ready
    my ( $r_in ) = '';
    vec( $r_in, fileno $self->{reader}, 1 ) = 1;
    my $nfound = select $r_in, undef, undef, undef;
    croak "error in select: $!\n" unless defined $nfound;

    my $n = sysread $self->{reader}, $$bufref, $len, $offset;
    croak "error in read: $!\n" unless defined $n;

    $n;
}

sub PRINT {
    my $self = shift;

    my $sep = defined $, ? $, : "";
    my $buf = join $sep, @_;

    $self->WRITE( $buf, length $buf, 0 );
}

sub PRINTF {
    my $self = shift;

    my $buf = sprintf @_;

    $self->WRITE( $buf, length $buf, 0 );
}

sub GETC {
    my $self = shift;

    my $c = undef;
    my $n = $self->READ( $c, 1, 0 );

    return undef unless $n;
    $c;
}

sub READLINE {
    my $self = shift;

    if ( $self->{eof} ) {
	# Clear EOF
	$self->{eof} = 0;
	return undef;
    }

    # Handle slurp mode
    if ( not defined $/ ) {
	my $buf	    = $self->{line_buffer};
	my $offset  = length $buf;
	while ( my $n = $self->READ( $buf, 4096, $offset ) ) {
	    $offset += $n
	}
	return $buf;
    }

    # Handle explicit RS
    if ( $/ ne "" ) {
	my $buf = $self->{line_buffer};
	while ( not $self->{eof} ) {

	    if ( length $buf != 0 ) {
		my $i;
		if ( ( $i = index $buf, $/ ) != -1 ) {
		    # Found end of line
		    $self->{line_buffer} = substr $buf, $i + length $/;

		    return substr $buf, 0, $i + length $/;
		}
	    }

	    # Read more data in our buffer
	    my $n = $self->READ( $buf, 4096, length $buf );
	    if ( $n == 0 ) {
		# Set EOF
		$self->{eof} = 1;
		return length $buf == 0 ? undef : $buf ;
	    }
	}
    } else {
	croak "FIXME: paragraph mode not implemented\n";
    }
}

sub CLOSE {
    my $self = shift;

    $self->done_writing;

    close $self->{reader}
      or croak "error closing reader pipe: $!\n";

    waitpid $self->{child}, 0;

    $self->{reader} = undef;
    $self->{writer} = undef;
}

1;

__END__

=pod

=head1 NAME

GnuPG::Tie::Encrypt - Tied filehandle interface to encryption with the GNU Privacy Guard.

GnuPG::Tie::Decrypt - Tied filehandle interface to decryption with the GNU Privacy Guard.

=head1 SYNOPSIS

    use GnuPG::Tie::Encrypt;
    use GnuPG::Tie::Decrypt;

    tie *CIPHER, 'GnuPG::Tie::Encrypt', armor => 1, recipient => 'User';
    print CIPHER <<EOF
This is a secret
EOF
    local $/ = undef;
    my $ciphertext = <CIPHER>;
    close CIPHER;
    untie CIPHER;

    tie *PLAINTEXT, 'GnuPG::Tie::Decrypt', passphrase => 'secret';
    print PLAINTEXT $ciphertext;
    my $plaintext = <PLAINTEXT>;

    # $plaintext should now contains 'This is a secret'
    close PLAINTEXT;
    untie PLAINTEXT

=head1 DESCRIPTION

GnuPG::Tie::Encrypt and GnuPG::Tie::Decrypt provides a tied  file handle
interface to encryption/decryption facilities of the GNU Privacy guard.

With GnuPG::Tie::Encrypt everyting you write to the file handle will be
encrypted. You can read the ciphertext from the same file handle.

With GnuPG::Tie::Decrypt you may read the plaintext equivalent of a
ciphertext. This is one can have been written to file handle.

All options given to the tie constructor will be passed on to the underlying
GnuPG object. You can use a mix of options to ouput directly to a file or
to read directly from a file, only remember than once you start reading
from the file handle you can't write to it anymore.


=head1 IMPLEMENTATIONS DETAILS

This interface will fork twice, once for the gnupg process and one the
controls the gpg process.

=head1 AUTHOR

Francis J. Lacoste <francis.lacoste@iNsu.COM>

=head1 COPYRIGHT

Copyright (c) 1999 Francis J. Lacoste and iNsu Innovations. inc.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 SEE ALSO

gpg(1) GnuPG(3)

=cut
