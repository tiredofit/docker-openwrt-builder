Drop .conf files here to apply ebtables rules.

Format: one rule per line, e.g.

  -A FORWARD -p IPv4 --ip-src 10.68.0.0/16 --ip-dst 10.68.1.153 -j ACCEPT
  -A FORWARD -p IPv4 --ip-src 10.68.1.153 --ip-dst 10.68.0.0/16 -j ACCEPT

Lines starting with # are comments.
Empty lines are ignored.

Apply with: apply-ebtables
