/-  *btc, bws=btc-wallet-store, bp=btc-provider
|%
::  req-id: hash of [xpub chyg idx]
::  back: lookup table of req-id -> requests from wallet-store
::
+$  back  (map req-id:bp request:bws)
+$  action
  $%  [%set-provider provider=ship]
  ==
--
