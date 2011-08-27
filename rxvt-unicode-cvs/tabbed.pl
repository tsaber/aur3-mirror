#!perl

sub refresh {
	my ($self) = @_;

	my $ncol = $self->ncol;

	my $text = " " x $ncol;
	my $rend = [($self->{rs_tabbar}) x $ncol];

	my @ofs;

	substr $text, 0, 1, "|";
	push @ofs, [0, 1, sub { $_[0]->new_tab }];

	my $ofs = 1;
	for my $tab (@{ $self->{tabs} }) {
		my $act = $tab->{activity} && $tab != $self->{cur} ? "*" : " ";
		my $txt = "$act$tab->{name}$act";
		my $len = length $txt;

		substr $text, $ofs, $len + 1, "$txt|";
		@$rend[$ofs .. $ofs + $len - 1] = ($self->{rs_tab}) x $len
			if $tab == $self->{cur};
		push @ofs, [ $ofs, $ofs + $len, sub { $_[0]->make_current ($tab) } ];

		$ofs += $len + 1;
	}

	$self->{tabofs} = \@ofs;

	$self->ROW_t ($self->nrow - 1, $text, 0, 0, $ncol);
	$self->ROW_r ($self->nrow - 1, $rend, 0, 0, $ncol);

	$self->want_refresh;
}

sub new_tab {
	my ($self, @argv) = @_;

	my $offset = $self->fheight;

	push @urxvt::TERM_INIT, sub {
		my ($term) = @_;
		$term->{parent} = $self;

	for (0 .. urxvt::NUM_RESOURCES - 1) {
		my $value = $self->{resource}[$_];

		$term->resource ("+$_" => $value)
			if defined $value;
	}

		$term->resource (perl_ext_2 => $term->resource ("perl_ext_2") . ",-tabbed");
		
	};

	push @urxvt::TERM_EXT, urxvt::ext::tabbed::tab::;

	my $term = new urxvt::term
		$self->env, $urxvt::RXVTNAME,
		-embed => $self->parent,
		@argv,
	;
}

sub configure {
	my ($self) = @_;

	my $tab = $self->{cur};

	$tab->XMoveResizeWindow (
		$tab->parent,
		0, 1,
		$self->width, $self->height - (@{ $self->{tabs} } > 1 ? $self->{tabheight} : 0)
	);
	$tab->XMoveResizeWindow (
		$tab->parent,
		0, 0,
		$self->width, $self->height - (@{ $self->{tabs} } > 1 ? $self->{tabheight} : 0)
	);
}

sub on_resize_all_windows {
	my ($self, $width, $height) = @_;

	1
}

sub copy_properties {
	my ($self) = @_;
	my $tab = $self->{cur};

	my $wm_normal_hints = $self->XInternAtom ("WM_NORMAL_HINTS");

	my $current = delete $self->{current_properties};

	for my $atom ($tab->XListProperties ($tab->parent)) {
		my ($type, $format, $items) = $self->XGetWindowProperty ($tab->parent, $atom);
		
		if ($atom == $wm_normal_hints && @{ $self->{tabs} } > 1) {
			my (@hints) = unpack "l!*", $items;
		
			$hints[$_] += $self->{tabheight} for (4, 6, 16);
		
			$items = pack "l!*", @hints;
		}

		my $cur = delete $current->{$atom};

		$self->XChangeProperty ($self->parent, $atom, $type, $format, $items)
			if $cur->[0] != $type or $cur->[1] != $format or $cur->[2] ne $items;

		$self->{current_properties}{$atom} = [$type, $format, $items];
	}

	$self->XDeleteProperty ($self->parent, $_) for keys %$current;
}

sub make_current {
	my ($self, $tab) = @_;

	if (my $cur = $self->{cur}) {
		delete $cur->{activity};
		$cur->XUnmapWindow ($cur->parent) if $cur->mapped;
		$cur->focus_out;
	}
	
	$self->{cur} = $tab;

	$self->configure;
	$self->copy_properties;
	
	$tab->focus_out;
	$tab->focus_in if $self->focus;
	
	$tab->XMapWindow ($tab->parent);
	delete $tab->{activity};
	$self->refresh;

	()
}

sub on_focus_in {
	my ($self, $event) = @_;

	$self->{cur}->focus_in;

	()
}

sub on_focus_out {
	my ($self, $event) = @_;

	$self->{cur}->focus_out;

	()
}

sub on_key_press {
	my ($self, $event) = @_;

	$self->{cur}->key_press ($event->{state}, $event->{keycode}, $event->{time});

	1
}

sub on_key_release {
	my ($self, $event) = @_;

	$self->{cur}->key_release ($event->{state}, $event->{keycode}, $event->{time});

	1
}

sub on_button_press {
	1
}

sub on_button_release {
	my ($self, $event) = @_;

	if ($event->{row} == $self->nrow - 1) {
		for my $button (@{ $self->{tabofs} }) {
			$button->[2]->($self, $event)
				if $event->{col} >= $button->[0]
					&& $event->{col} < $button->[1];
		}
	}

	1
}

sub on_motion_notify {
	1
}

sub on_init {
	my ($self) = @_;

	$self->{resource} = [map $self->resource ("+$_"), 0 .. urxvt::NUM_RESOURCES - 1];

	$self->resource (int_bwidth => 0);
	$self->resource (name => "URxvt.tabbed");
	$self->resource (pty_fd => -1);

	$self->option ($urxvt::OPTION{scrollBar}, 0);

	my $fg    = $self->x_resource ("tabbar-fg");
	my $bg    = $self->x_resource ("tabbar-bg");
	my $tabfg = $self->x_resource ("tab-fg");
	my $tabbg = $self->x_resource ("tab-bg");

	defined $fg    or $fg    = -2;
	defined $bg    or $bg    = -1;
	defined $tabfg or $tabfg = -1;
	defined $tabbg or $tabbg = -2;

	$self->{rs_tabbar} = urxvt::SET_COLOR (urxvt::DEFAULT_RSTYLE, $fg    + 2, $bg    + 2);
	$self->{rs_tab}    = urxvt::SET_COLOR (urxvt::DEFAULT_RSTYLE, $tabfg + 2, $tabbg + 2);

	()
}

sub on_start {
	my ($self) = @_;

	$self->{tabheight} = $self->int_bwidth + $self->fheight + $self->lineSpace;

	$self->cmd_parse ("\033[?25l");

	my @argv = $self->argv;

	do {
		shift @argv;
	} while @argv && $argv[0] ne "-e";

	$self->new_tab (@argv);

	()
}

sub on_configure_notify {
	my ($self, $event) = @_;

	$self->configure;
	$self->refresh;

	()
}

sub on_wm_delete_window {
	my ($self) = @_;

	$self->{destroy} = urxvt::iw->new->start->cb (sub { $self->destroy });
	$_->destroy for @{ $self->{tabs} };

	1
}

sub tab_start {
	my ($self, $tab) = @_;

	$tab->XChangeInput ($tab->parent, urxvt::PropertyChangeMask);

	push @{ $self->{tabs} }, $tab;

	$tab->{name} ||= @{ $self->{tabs} } - 1;
	my @t = reverse sort { $a->{name} <=> $b->{name} } @{ $self->{tabs} };
	$tab->{name} = $t[0]->{name} + 1;
	$self->make_current ($tab);

	()
}

sub tab_destroy {
	my ($self, $tab) = @_;

	my ($idx) = grep $self->{tabs}[$_] == $tab, 0 .. $#{ $self->{tabs} };
	$idx = -1 if $idx == @{ $self->{tabs} } - 1;
	$self->{tabs} = [ grep $_ != $tab, @{ $self->{tabs} } ];

	if (@{ $self->{tabs} }) {
		if ($self->{cur} == $tab) {
			delete $self->{cur};
			$self->make_current ($self->{tabs}[$idx]);
		} else {
			$self->refresh;
		}
	} else {
		$self->new_tab if ! $self->{destroy};
	}

	()
}

sub tab_key_press {
	my ($self, $tab, $event, $keysym, $str) = @_;

	if ($event->{state} & urxvt::ShiftMask) {
		if ($keysym == 0xff51 || $keysym == 0xff53) {
			my ($idx) = grep $self->{tabs}[$_] == $tab, 0 .. $#{ $self->{tabs} };

			--$idx if $keysym == 0xff51;
			++$idx if $keysym == 0xff53;

			$self->make_current ($self->{tabs}[$idx % @{ $self->{tabs}}]);

			return 1;
		} elsif ($keysym == 0xff54) {
			$self->new_tab;

			return 1;
		} elsif ($keysym == 0xff52 && @{ $self->{tabs} } == 1) {
			$tab->{name} = 1;

			return 1;
		}
	} elsif ($event->{state} & urxvt::ControlMask) {
		if ($keysym == 0xff51 || $keysym == 0xff53) {
			my ($idx1) = grep $self->{tabs}[$_] == $tab, 0 .. $#{ $self->{tabs} };
			my  $idx2  = ($idx1 + ($keysym == 0xff51 ? -1 : +1)) % @{ $self->{tabs} };

			($self->{tabs}[$idx1], $self->{tabs}[$idx2]) =
				($self->{tabs}[$idx2], $self->{tabs}[$idx1]);

			$self->make_current ($self->{tabs}[$idx2]);

			return 1;
		}
	}

	()
}

sub tab_property_notify {
	my ($self, $tab, $event) = @_;

	$self->copy_properties
		if $event->{window} == $tab->parent;

	()
}

sub tab_activity {
	my ($self, $tab) = @_;

	$self->refresh;
}

package urxvt::ext::tabbed::tab;

{
	for my $hook qw(start destroy key_press property_notify) {
		eval qq{
			sub on_$hook {
				my \$parent = \$_[0]{term}{parent}
					or return;
				\$parent->tab_$hook (\@_)
			}
		};
		die if $@;
	}
}

sub on_add_lines {
	$_[0]->{activity}++
		or $_[0]{term}{parent}->tab_activity ($_[0]);
	()
}
