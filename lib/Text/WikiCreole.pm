package Text::WikiCreole;
require Exporter;
@ISA = (Exporter);
@EXPORT = qw(%creole_tags creole_parse creole_plugin creole_link creole_extend);
use vars qw(%creole_tags $VERSION);
use strict;
use warnings;

our $VERSION = "0.01";

# order matters for performance.  for inline, first should
# be 'plain', second 'esc', last 'any'.  the rest in order of most common.  
my @strict_inline = ( # @inline set to this by default
  'plain', 'esc', 'link', 'nlink', 'strong', 'br', 'inowiki', 'img', 'em', 
  'plug', 'any'
);
my @extended_inline = ( # optionally appended to @inline
  'sup', 'sub', 'u', 'mono'
);
my @strict_blocks = ( # @blocks set to this by default
  'p', 'h1', 'h2', 'h3', 'ul', 'ol', 'hr', 'table', 'h4', 'h5', 
  'h6', 'nowiki', 'plug'
);
my @extended_blocks = ( # optionally appended to @blocks
  'ip', 'dl'
);

# default to strict.  switch to extended with creole_extend(1)
my @inline = @strict_inline;
my @blocks = @strict_blocks;

BEGIN {
  %creole_tags = (
    hr => { open => "<hr />\n", close => "" },
    br => { open => "<br />", close => "" },
    li => { open => "<li>", close => "</li>\n" },
    ol => { open => "<ol>\n", close => "</ol>\n" },
    ul => { open => "<ul>\n", close => "</ul>\n" },
    table => { open => "<table>\n", close => "</table>\n" },
    tr => { open => "<tr>\n", close => "</tr>\n" },
    td => { open => "<td>", close => "</td>\n" },
    th => { open => "<th>", close => "</th>\n" },
    strong => { open => "<strong>", close => "</strong>" },
    em => { open => "<em>", close => "</em>" },
    inowiki => { open => "<tt>", close => "</tt>" },
    sup => { open => "<sup>", close => "</sup>" },
    sub => { open => "<sub>", close => "</sub>" },
    u => { open => "<u>", close => "</u>" },
    p => { open => "<p>", close => "</p>\n" },
    ip => { open => "<div style=\"margin-left: 2em\">", close => "</div>\n" },
    dl => { open => "<dl>\n", close => "</dl>\n" },
    dt => { open => "<dt>", close => "</dt>\n" },
    dd => { open => "<dd>", close => "</dd>\n" },
    nowiki => { open => "<pre>\n", close => "</pre>\n" },
    mono => { open => "<tt>", close => "</tt>" },
    h1 => { open => "<h1>", close => "</h1>\n" },
    h2 => { open => "<h2>", close => "</h2>\n" },
    h3 => { open => "<h3>", close => "</h3>\n" },
    h4 => { open => "<h4>", close => "</h4>\n" },
    h5 => { open => "<h5>", close => "</h5>\n" },
    h6 => { open => "<h6>", close => "</h6>\n" },
    a => { open => "<a href=", close => "</a>" },
    link => { open => "", close => "" },
    nlink => { open => "", close => "" },
    img => { open => "<img ", close => " />" },
    esc => { open => "", close => "" },
    plain => { open => "", close => "" },
    any => { open => "", close => "" },
    url => { open => "", close => "" },
    top => { open => "", close => "" },
    plug => { open => "", close => "" },
  );
}

# a bunch of handy patterns
my $s = qr/\ */;                    # optional space
my $bl = qr/$s\n/s;                 # blank to end of line
my $bls = qr/(?:$bl)*/s;            # optional consecutive blank lines
my $nbl = qr/[^\n]*?\S.*?\n/s;      # non-blank line
my $l = qr/.*?\n/s;                 # rest of current line
my $head = qr/$s=$s[^=]+$s=*$bl/;   # heading
my $hr = qr/$s-{4,}$bl/s;           # horizontal line
my $now = qr/\{{3}$bl$l*\}{3}$bl/s; # nowiki block
my $plug = qr/$s\<\<.*?\>\>/s;      # plugin block
my $tbl = qr/$s\|/s;                # table 
my $ino = qr/\{{3}/s;               # nowiki inline
my $list = qr/$s[\*\#][^\*\#]/;     # list
my $ip = qr/:$s\S/;                 # indented paragraph
my $dl = qr/;$s\S/;                 # definition list
my $str = qr/\*\*[^\*].*?\*\*/s;    # strong
my $esc = qr/~/;                    # escape character
my $ne = qr/(?<!$esc)/;             # no escape char preceding
sub eatwhite {                      # eat consecutive blank lines
  $_[0] =~ s/$bls$//s;
  return $_[0];
}  

# shorthand for the plain block below. 
my $in_ext = qr/(?!\*\*|\\\\|\/\/|\{\{|\[\[|\<\<|\,\,|\^\^|__|\#\#|$esc|https?:\/\/|ftp:\/\/)/s;
my $in_str = qr/(?!\*\*|\\\\|\/\/|\{\{|\[\[|\<\<|$esc|https?:\/\/|ftp:\/\/)/s;
my $in = $in_str; # default to strict

my %grammar = (
    top => { # special block, which matches all and launches the others
      match => qr/^(.*)/s,
      blocks => \@blocks,
    },
    p => { # paragraph
      match_ext => qr/^(?!$ip|$dl)$bls((?:(?!$head|$list|$hr|$now|$plug|$tbl|$ip|$dl)$nbl)+)$bls/s,
      # keep the next 2 identical
      match_str => qr/^$bls((?:(?!$head|$list|$hr|$now|$plug|$tbl)$nbl)+)$bls/s,
      match =>     qr/^$bls((?:(?!$head|$list|$hr|$now|$plug|$tbl)$nbl)+)$bls/s,
      filter => \&eatwhite,
      blocks => \@inline,
    },
    ip => { # indented paragraph
      match => qr/^:((?:(?!$head|$list|$hr|$now|$plug|$tbl|$dl)$nbl)+)$bls/s,
      filter => sub { $_[0] =~ s/^://mg; return $_[0]; },
      blocks => ['p', 'ip'],
    },
    dl => { # definition list
      match => qr/^(;(?:(?!$list|$now|$head|$hr|$plug|$tbl)$nbl)+)$bls/s,
      blocks => ['dt', 'dd', 'any'],
    },
    dt => { # definition title
      match => qr/^;$s((?:.(?!(?<!$esc):))*.?)/s,
      filter => sub { $_[0] =~ s/\s$//s; return $_[0]; },
      blocks => \@inline,
    },
    dd => { # definition list
      match => qr/^:$s((?:.(?!(?<!$esc)[;:]))*.?)/s,
      filter => sub { $_[0] =~ s/\s$//s; return $_[0]; },
      blocks => \@inline,
    },
    h1 => {
        match => qr/^$s=$s([^=].*?)$s=*$bl$bls/s,
        blocks => \@inline,
    },
    h2 => {
        match => qr/^$s={2}$s([^=].*?)$s=*$bl$bls/s,
        blocks => \@inline,
    },
    h3 => {
        match => qr/^$s={3}$s([^=].*?)$s=*$bl$bls/s,
        blocks => \@inline,
    },
    h4 => {
        match => qr/^$s={4}$s([^=].*?)$s=*$bl$bls/s,
        blocks => \@inline,
    },
    h5 => {
        match => qr/^$s={5}$s([^=].*?)$s=*$bl$bls/s,
        blocks => \@inline,
    },
    h6 => {
        match => qr/^$s={6}$s([^=].*?)$s=*$bl$bls/s,
        blocks => \@inline,
    },
    ul => {
        match => qr/^`?$s(\*[^\*]$l(?:(?!$head|$now|`|$hr|$tbl)$nbl)*)$bls/s,
        filter => sub { 
          $_[0] =~ s/^$s[\*\#]([^\*\#])/\`$1/mg; 
          $_[0] =~ s/^$s[\*\#]//mg;
          return $_[0];
        },
        blocks => ['ul', 'ol', 'li'],
    },
    ol => {
        match => qr/^`?$s(\#[^\#]$l(?:(?!$head|$now|`|$hr|$tbl)$nbl)*)$bls/s,
        filter => sub { 
          $_[0] =~ s/^$s[\*\#]([^\*\#])/\`$1/mg; 
          $_[0] =~ s/^$s[\*\#]//mg;
          return $_[0];
        },
        blocks => ['ul', 'ol', 'li'],
    },
    table => {
        match => qr/^($s\|.*$bl)+$bls/s,
        blocks => ['tr'],
    },
    tr => {
        match => qr/^$s(\|.*?)\|?$bl/s,
        blocks => ['th', 'td'],
    },
    td => {
        match => qr/^\|$s([^\|]*)/,
        blocks => \@inline,
        filter => sub { $_[0] =~ s/$s$//; return $_[0]; }
    },
    th => {
        match => qr/^\|=$s([^\|]*)/,
        blocks => \@inline,
        filter => sub { $_[0] =~ s/$s$//; return $_[0]; }
    },
    plug => { 
        match => qr/^$s\<{2}(.*?\>*)$ne\>{2}(?:$bl$bls)?/s,
    },        
    nowiki => {
        match => qr/^\{{3}$bl((?:$l)*?\})\}\}$bl$bls/s,
        filter => sub { 
          $_[0] =~ s/\}$//s; 
          $_[0] =~ s/\&/\&amp;/gs;
          $_[0] =~ s/\</\&lt;/gs;
          $_[0] =~ s/\>/\&gt;/gs;
          return $_[0]; 
        }
    },
    hr => {
        match => qr/^$s(-)-{3,}$bl$bls/s,
        filter => sub { $_[0] =~ s/-//; return $_[0]; }
    },
    # inline stuff below here
    em => {
        match => qr/^\/\/([^\/].*?)(?:$ne\/\/|$)/s,
        blocks => \@inline,
    },
    strong => {
        match => qr/^\*\*([^\*].*?)(?:$ne\*\*|$)/s,
        blocks => \@inline,
    }, 
    sup => {
        match => qr/^\^\^([^\^].*?)(?:$ne\^\^|$)/s,
        blocks => \@inline,
    }, 
    sub => {
        match => qr/^\,\,([^\,].*?)(?:$ne\,\,|$)/s,
        blocks => \@inline,
    }, 
    u => {
        match => qr/^__([^_].*?)(?:${ne}__|$)/s,
        blocks => \@inline,
    }, 
    mono => {
        match => qr/^\#\#([^\#].*?)(?:${ne}\#\#|$)/s,
        blocks => \@inline,
    }, 
    li => {
        match => qr/^\`$s($l(?:[^\`\*\#]$l)*)/s,
        blocks => \@inline,
        filter => \&eatwhite
    },
    br => {
        match => qr/^(\\)\\/,
        filter => sub { $_[0] =~ s/.//; return $_[0]; }
    },
    inowiki => {
        match => qr/^\{\{(\{.*?\}*)\}{3}/s,
        filter => sub { 
          $_[0] =~ s/^\{//; 
          $_[0] =~ s/\&/\&amp;/gs;
          $_[0] =~ s/\</\&lt;/gs;
          $_[0] =~ s/\>/\&gt;/gs;
          return $_[0]; }
    },
    img => { 
        match => qr/^\{\{([^\{].*?)$ne\}\}/s,
        filter => sub {
          $_[0] =~ m/([^\|]*)\|?(.*)/; 
          my $i = $1; my $a = $2;
          $a = "" unless $a; 
          $i =~ s/$s(.*?)$s$/$1/;
          return qq|src="$i" alt="$a"|;
        }
    },
    link => { # link in [[ double brackets ]]
        match => qr/^\[\[([^\[].*?)$ne\]\]/s,
        blocks => ['url', 'plain', 'img', 'em', 'strong', 'any'],
        filter => sub {
          $_[0] =~ m/([^\|]*)\|?(.*)/; 
          my $l = $1; my $t = $2;
          $t = $l unless $t; 
          $l =~ s/(?:^$s|$s$)//g;
          $t =~ s/(?:^$s|$s$)//g;
          return "$creole_tags{a}{open}\"$l\">$t$creole_tags{a}{close}";
        }
    },
    nlink => { # naked URLs
        match => qr/^((?:http:|https:|ftp:)\/\/[^\s]*)/s,
        filter => sub {
          if($_[0] =~ m/(.*?)([\(\,\.\?\!\:\;\"\'\)])$/s) {
            return "$creole_tags{a}{open}\"$1\">$1$creole_tags{a}{close}$2";
          } else {
            return "$creole_tags{a}{open}\"$_[0]\">$_[0]$creole_tags{a}{close}";
          }
        }
    },
    # prevent markup in links until after <a href=...>
    url => { match => qr/^(\<[^\<\>]*\>)/ }, 
    # match the escape character not followed by whitespace
    esc => { match => qr/^$esc([^\s])/ },
    # match all text up to the next inline markup
    plain => { match => qr/^($in(?:.$in)*.?)/s },
    # last resort.  matches any 1 character.
    any => { match => qr/^(.)/, },

);

sub gerror {
  print STDERR "Grammar error: $_[0]\n";
}

sub parse {
  my ($text, $block) = @_; $block = "top" unless $block;
  my $html;

  # sanity checking
  if(! $grammar{$block}{match}) { return ""; }
  return "" unless $$text =~ /$grammar{$block}{match}(.*)/s;
  if(! ($1 && length($1) > 0)) { return ""; }

  my $chunk = $1; $$text = $2; 
  if(ref $grammar{$block}{filter}) {
    $chunk = &{$grammar{$block}{filter}}($chunk);
  }
  $html .= $creole_tags{$block}{open};
  if(ref $grammar{$block}{blocks}) {
    while(my $l = $chunk) {
      for (@{$grammar{$block}{blocks}}) {
        if(my $z = parse(\$chunk, $_)) {
          $html .= $z;
          last;
        }
      }
      if($l eq $chunk) { 
        gerror "Block '$block' did not reduce text: -$l-"; 
        last;
      }
    }
  } else {
    $html .= $chunk;
  }
  return($html . $creole_tags{$block}{close});
}

# exported parse function.  copy input, then parse, since parse modifies the source
sub creole_parse {
  my ($text) = @_;
  return parse \$text;
}

# exported function to register a plugin to digest << plugins >> 
sub creole_plugin {
  $grammar{plug}{filter} = $_[0];
}

# exported function to register a filter to customize internal wiki links
sub creole_link {
  $grammar{url}{filter} = $_[0];
}

# exported function switches from default strict syntax to extended syntax
sub creole_extend {
  # add the inline extensions *before* the last item, which is
  # the catchall 'any' 
  splice @inline, @inline - 1, 0, @extended_inline;
  splice @blocks, @blocks, 0, @extended_blocks;
  ## a hack follows.  Not the least bit elegant...
  $grammar{p}{match} = $grammar{p}{match_ext};
  $in = ${in_ext};
  $grammar{plain}{match} = qr/^($in(?:.$in)*.?)/s; # recompile after changing $in
}

1;
__END__


=head1 NAME

Text::WikiCreole - Convert Wiki Creole 1.0 markup to XHTML

=head1 VERSION

Version 0.01

=head1 DESCRIPTION

Text::WikiCreole implements the Wiki Creole markup language, 
version 1.0, as described at http://www.wikicreole.org.  It
reads Creole 1.0 markup and returns XHTML.

=head1 SYNOPSIS

 use Text::WikiCreole;
 creole_extend;            # use optional extensions to Creole 1.0
 creole_plugin \&myplugin; # register custom plugin parser

 my $html = creole_parse($creole_text);
 ...

=head1 FUNCTIONS

=head2 creole_parse

    Self-explanatory.  Takes a Creole markup string argument and 
    returns HTML. 

=head2 creole_extend

    By default, Text::WikiCreole implements strict Creole 1.0,
    summarized in STRICT MARKUP below.

    creole_extend() enables support for the additional markup 
    described in EXTENDED MARKUP below.

=head2 creole_plugin

    Creole 1.0 supports a plugin syntax: << plugin content >>

    Write a function that receives the text between the <<>> 
    delimiters as $_[0] (and not including the delimiters) and 
    returns the text to be displayed.  For example, here is a 
    simple plugin that converts plugin text to uppercase:

    sub uppercase_plugin {
      $_[0] =~ s/([a-z])/\u$1/gs;
      return $_[0];
    }
    creole_plugin \&uppercase_plugin;

=head2 creole_link

    You may wish to customize [[ links ]], such as to prefix a hostname,
    port, etc.

    Write a function, similar to the plugin function, which receives the
    <a href="pagename"> part of the link as $_[0] and returns the 
    customized link.  For example, to prepend "http://my.domain/" to
    pagename:

    sub mylink {
      $_[0] =~ s%href=\"%href=\"http://my.comain/%;
      return $_[0];
    }
    creole_link \&mylink;

=head1 VARIABLES

=head2 %creole_tags

    You may wish to customize the opening and/or closing tags
    for the various bits of Creole markup.  For example, to
    assign a CSS class to list items:
 
    $creole_tags{li}{open} = "<li class=myclass>";

    Or to see the current open tag for indented paragraphs:

    print "$creole_tags{ip}{open}\n";

    The tags that may be of interest are:

    hr          br          li
    ol          ul          table
    tr          th          td
    strong      em          inowiki (inline nowiki syntax)
    nowiki      sup         sub
    u           p           ip (indented paragraphs)
    dl          dt          mono (monospace)
    dd          h1          h2
    h3          h4          h5
    h6          a           img

=head1 STRICT MARKUP
 
    Here is a summary of the official Creole 1.0 markup 
    elements.  See http://www.wikicreole.org for the full
    details.

    Headings:
    = heading 1       ->    <h1>heading 1</h1>
    == heading 2      ->    <h2>heading 2</h2>
    ...
    ====== heading 6  ->    <h6>heading 6</h6>
   
    Various inline markup:
    ** bold **        ->    <strong> bold </strong>
    // italics //     ->    <em> italics </em>
    **// both //**    ->    <strong><em> both </em></strong>
    [[ link ]]        ->    <a href="link">link</a>
    [[ link | text ]] ->    <a href="link">text</a>
    http://cpan.org   ->    <a href="http://cpan.org">http://cpan.org</a>
    line \\ break     ->    line <br /> break
    {{img.jpg|alt}}   ->    <img src="img.jpg" alt="alt">

    Lists:
    * unordered list        <ul><li>unordered list</li>
    * second item               <li>second item</li>
    ## nested ordered  ->       <ol><li>nested ordered</li>
    *** uber-nested                 <ul><li>uber-nested</li></ul>
    * back to level 1           </ol><li>back to level 1</li></ul>

    Tables:
    |= h1 |= h2       ->    <table><tr><th>h1</th><th>h2</th></tr>
    |  c1 |  c2             <tr><td>c1</td><td>c2</td></tr></table>

    Nowiki (Preformatted):
    {{{                     <pre>
      ** not bold **          ** not bold **
      escaped HTML:   ->      escaped HTML:
      <i> test </i>           &lt;i&gt; test &lt;/i&gt;
    }}}                     <pre>

    {{{ inline\\also }}} -> <tt>inline\\also</tt>

    Escape Character:
    ~** not bold **    ->    ** not bold **
    tilde: ~~          ->    tilde: ~

    Plugins:
    << plugin >>       ->    whatever you want

    Paragraphs are separated by other blocks and blank lines.  
    Inline markup can usually be combined, overlapped, etc.  List
    items and plugin text can span lines.

=head1 EXTENDED MARKUP

    In addition to STRICT MARKUP, Text::WikiCreole optionally supports
    the following markup:

    Inline:
    ## monospace ##     ->    <tt> monospace </tt>
    ^^ superscript ^^   ->    <sup> superscript </sup>
    ,, subscript ,,     ->    <sub> subscript </sub>
    __ underline __     ->    <u> underline </u>
    (TM)                ->    &trade;
    (R)                 ->    &reg;
    (C)                 ->    &copy;
    ...                 ->    &hellip;
    --                  ->    &ndash;

    Indented Paragraphs:
    :this               ->    <div style="margin-left:2em"><p>this
    is indented               is indented</p>
    :: more indented          <div style="margin-left:2em"><p> more
                              indented</div></div>

    Definition Lists:
    ; Title             ->    <dl><dt>Title</dt>
    : item 1 : item 2         <dd>item 1</dd><dd>item 2</dd>
    ; Title 2 : item2a        <dt>Title 2</dt><dd>item 2a</dd></dl>

=head1 AUTHOR

Jason Burnett, C<< <jason at jnj.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-text-wikicreole at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Text-WikiCreole>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Text::WikiCreole

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Text-WikiCreole>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Text-WikiCreole>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-WikiCreole>

=item * Search CPAN

L<http://search.cpan.org/dist/Text-WikiCreole>

=back

=head1 ACKNOWLEDGEMENTS

The parsing algorithm is basically the same as (and inspired by)
the one in Document::Parser.  Document::Parser is OO and is, 
as such, incompatible with my brain.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Jason Burnett, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

