# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Bugzilla Bug Tracking System.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#
# Contributor(s): Terry Weissman <terry@mozilla.org>
#                 Dan Mosedale <dmose@mozilla.org>
#                 Joe Robins <jmrobins@tgix.com>
#                 Dave Miller <justdave@syndicomm.com>
#                 Christopher Aillon <christopher@aillon.com>
#                 Gervase Markham <gerv@gerv.net>
#                 Christian Reis <kiko@async.com.br>
#                 Bradley Baetz <bbaetz@acm.org>
#                 Erik Stambaugh <erik@dasbistro.com>
#                 Max Kanat-Alexander <mkanat@bugzilla.org>

package Bugzilla::Auth::Login::CGI;
use strict;
use base qw(Bugzilla::Auth::Login);
use constant user_can_create_account => 1;

use Bugzilla::Constants;
use Bugzilla::WebService::Constants;
use Bugzilla::Util;
use Bugzilla::Error;
use Bugzilla::Auth::Login::Cookie qw(valid_login_cookie);

sub requires_verification {
    return exists $_[0]->{'requires_verification'} ? $_[0]->{'requires_verification'} : 1;
}

sub get_login_info {
    my ($self) = @_;
    my $params = Bugzilla->input_params;

    # Check if a token was passed in via requests for WebServices
    my $token  = trim(delete $params->{"Bugzilla_token"});
    if (defined $token) {
        my ($user_id, $login_token) = split('-', $token, 2);
        if (!detaint_natural($user_id) || !$login_token) {
            return { failure => AUTH_NODATA };
        }

        # Since the login token is basically the same as the cookies
        # normally stored for a user session, we use the same call to
        # verify the validity of the login token. Also if token is valid
        # skip DB verification.
        if (valid_login_cookie($user_id, $login_token)) {
            $self->{'requires_verification'} = 0;
            return { user_id => $user_id };
        }
        else {
            return { failure => AUTH_LOGINFAILED };
        }
    }

    my $username = trim(delete $params->{"Bugzilla_login"});
    my $password = delete $params->{"Bugzilla_password"};

    if (!defined $username || !defined $password) {
        return { failure => AUTH_NODATA };
    }

    return { username => $username, password => $password };
}

sub fail_nodata {
    my ($self) = @_;
    my $cgi = Bugzilla->cgi;
    my $template = Bugzilla->template;

    if (Bugzilla->usage_mode != USAGE_MODE_BROWSER) {
        ThrowUserError('login_required');
    }

    print $cgi->header();
    $template->process("account/auth/login.html.tmpl",
                       { 'target' => $cgi->url(-relative=>1) }) 
        || ThrowTemplateError($template->error());
    exit;
}

1;
