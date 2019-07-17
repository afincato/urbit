/-  ring
::
::  To post to /board/1234, you must post:
::
::  [outer-sig [/board/1234 [signature %post blah]]]
::
::  In turn, the processing goes like this:
::
::  - Checks outer-signature.
::
::  - Calls (on-route-for-child:toplevel outer-sig ~ /), which can kill the
::  processing or can send a piece of data downwards
::
::  - Calls (on-route-for-child:board outer-sig ~ /board), which can kill or send
::  a piece of data downwards. In this case, a new post number is allocated and
::  is sent downwards between nodes...
::
::  - Calls (on-incoming-event:post outer-sig [~ postid=523] /board/1234
::  signature [%post blah]), which can cancel the event or can add its own
::  private data. In this case, it adds the postid allocated by its parent and
::  then 

|%
::  TODO: REAL TYPES
::
++  ring-sig  @
::
+$  post
  $:  =ring-sig
  ::
      subject=@t
      text=@t
  ==
::
+$  on-process-response
  $%  ::  emits an event to this node's event log with a corresponding piece of data
      ::
      [%log private-event=vase return-event=vase]
      ::  creates a new node and re-dispatch the event to it
      ::
      [%create sub-id=@t type=@t child-event=vase]
      ::  returns a value upwards
      ::
      [%return return-event=vase]
  ==
::  the authenticating toplevel node
::
++  node-type-auth
  |%
  ++  parent-event
    ring-sig
  ::
  +$  child-event
    ring-sig
  ::  user events which target the toplevel node are all about doing membership checks
  ::
  +$  user-event
    $%  [%init community-name=@t host-ship=@p initial-members=(set @p)]
        [%add-member ship=@p]
        [%remove-member ship=@p]
    ==
  ::
  +$  private-event
    ~
  ::
  +$  private-state
    ::  todo: don't leave all mods as a having the same power this is how
    ::  communities get destroyed
    $:  mods=(set @p)
    ==
  ::
  +$  snapshot
    $:  invited=(set @p)
    ==
  ::
  +$  child-returned
    $%  [%accept ~]
        [%reject ~]
    ==
  ::
  +$  return-event
    $%  [%accept ~]
        [%reject ~]
    ==
  ::
  +$  on-process-response
    $:  [%log =private-event =return-event]
    ==
  ::  +on-route: everything routes through the toplevel node. this is what does 
  ::
  ++  on-route
    |=  [=path =parent-event =private-state]
    ^-  (unit child-event)
    ::
    ~&  [%todo-add-auth-check-for parent-event]
    ::
    `parent-event
  ::
  ++  on-process-event
    |=  [=parent-event =user-event =private-state]
    ^-  [on-process-response _private-state]
    ::  todo: since we're the toplevel node, we also need to perform auth here.
    ::
    !!
  --
::  the board node: toplevel auth owns nodes
::
++  node-type-board
  |%
  ++  parent-event
    ring-sig
  ::  the board passes the newly allocated id to the thread
  ::
  +$  child-event
    id=@ud
  ::  the user-event of the board is a new post request
  ::
  +$  user-event
    $%  [%new-post =post]
::        [%delete-post =post]
    ==
  ::
  +$  private-event
    ~
  ::
  +$  private-state
    $:  next-postid=_1
        other=@
    ==
  ::
  +$  snapshot
    ~
  ::
  +$  child-returned
    ::  return-event:node-type-thread
    $%  [%accepted id=@u]
        [%ignored id=@u]
    ==
  ::
  +$  return-event
    $%  [%accept ~]
        [%reject ~]
    ==
  ::
  +$  on-process-response
    $:  [%create id=@t type=@t =child-event]
    ==
  ::  +on-route: called when we must route a message to our children
  ::
  ::    In the +on-route phase, we take the input parent-event and calculate
  ::    what the child-event we give to the next path segment is, with the
  ::    ability to halt the processing of this event by returning ~.
  ::
  ++  on-route
    |=  [=path =parent-event =private-state]
    ^-  (unit child-event)
    ::  we could block the route if we wanted here!
    ::
    `next-postid.private-state
  ::  +on-process-event: called when we give the passed in user-event to its
  ::  target node.
  ::
  ::    In the +on-process-event phase, we take the parent-event and the
  ::    user-event that the user passed to, and create a list of effects along
  ::    with modifications to private state that the user never sees.
  ::
  ++  on-process-event
    |=  [=parent-event =user-event =private-state]
    ^-  [on-process-response _private-state]
    ::
    ?-    -.user-event
        %new-post
      =^  id  private-state
        [next-postid.private-state private-state(next-postid +(next-postid.private-state))]
      ::
      [[%create (scot %ud id) %thread id] private-state]
    ==
  ::  +apply-event-to-snapshot: called to replay the event log
  ::
  ::    In the +apply-event-to-snapshot phase, we take a %log event generated
  ::    from +on-process-event and modify the snapshot. Behind the scenes, the
  ::    event log is synced to clients, who call this to update their own
  ::    snapshots of the current state.
  ::
  ++  apply-event-to-snapshot
    |=  [=user-event =private-event =snapshot]
    ^-  _snapshot
    ~&  %todo
    snapshot
  ::  +on-child-return: called on parent nodes when +on-process-event creates a %return-event
  ::
  ::    In the +on-return-event phase, we take a %return event generated by a
  ::    child node and modify the state with it. This is how 
  ::
  ++  on-child-return
    |=  [=child-returned =private-state]
    ^-  [return-event _private-state]
    ?-    -.child-returned
        %accepted
      ~&  %accepted
      ?>  =(id.child-returned next-postid.private-state)
      [[%accept ~] private-state(next-postid +(next-postid.private-state))]
    ::
        %ignored
      ~&  %ignored
      [[%accept ~] private-state]
    ==
  --
::
::  Inside a node, you have
::
++  node-type-thread
  |%
  ::
  :::::::::::::::::::: EVENT TYPES
  ::
  ::  the parent-event of thread is a board issued id number
  ::
  ++  parent-event
    child-event:node-type-board
  ::  the child-event of the toplevel is ~. The toplevel has no 
  ::
  +$  child-event
    ~
  ::  the user-event of the toplevel is a signed post
  ::
  +$  user-event
    $:  [%new-post =post]
    ==
  ::  the private-event of a thread is the additional metadata
  ::
  +$  private-event
    $:  ::  the post-id is assigned server side
        ::
        id=@ud
        ::  the date assigned on the server side (never trust the client)
        ::
        date=@da
    ==
  ::  +return-event: passed back to our parent
  ::
  +$  return-event
    $%  [%accepted id=@u]
        [%ignored id=@u]
    ==
  ::
  :::::::::::::::::::: OTHER DATA
  ::
  ::  the snapshot of a thread is all its posts plus metadata
  ::
  +$  snapshot
    $:  posts=(list [user-event private-event])
        ::
        ::posters=@
    ==
  ::
  +$  private-state
    ~
  ::
  +$  on-process-response
    $%  [%log =private-event =return-event]
    ==
  ::
  :::::::::::::::::::: FLOW CONTROL
  ::
  ++  on-process-event
    |=  [=parent-event =user-event =private-state]
    ^-  [on-process-response _private-state]
    ::
    =/  id  id.parent-event
    [[%log [id ~2019.5.5] [%accepted id]] private-state]
  ::  applies an event or fails
  ::
  ++  apply-event-to-snapshot
    |=  [=user-event private=private-event =snapshot]
    ^-  _snapshot
    ::
    snapshot(posts [[user-event private] posts.snapshot])
  --
::
++  event-log-item
  $%  ::  when sending across the wire, just send the value in the vase, not
      ::  the type. the other side knows what app its for and at least for now,
      ::  the remote will call the mold.
      [%log user-event=vase private-event=vase]
      [%create sub-id=@t type=@t]
  ==
::
++  app-map
  ^-  (map @t vase)
  (my [[%board !>(node-type-board)] [%thread !>(node-type-thread)] ~])
::  currently a hack. to make this work really generically, we'll need to make
::  things sorta vase based where we connect types pulled out of the vases
::  instead of an each of the two types.
::
++  node-state
  $~  [%board 1 ~ *vase *vase ~]
  $:  app-type=@t
      next-event-id=@ud
      event-log=(list [id=@ud =event-log-item])
      snapshot=vase
      private-state=vase
      children=(map @t node-state)
  ==
::  +sump: like arvo sump, translates vases into cards between applets
::
++  sump
  |=  wec/vase
  ^-  on-process-response
  ::
  =.  wec  (sped wec)
  =/  tag  (slot 2 wec)
  ?+    q.tag  !!
      %log
    =/  private-event  (slot 6 wec)
    =/  return-event  (slot 7 wec)
    [%log private-event return-event]
  ::
      %create
    =/  id  (slot 6 wec)
    =/  type  (slot 14 wec)
    =/  child-event  (slot 15 wec)
    [%create ;;(@t q.id) ;;(@t q.type) child-event]
  ::
      %return
    =/  event  (slot 3 wec)
    [%return event]
  ==
::  all hail joe for this
::
++  bunt-a-vase
  |=  v=vase
  ^-  vase
  (slap v [%kttr [%like [[%& 1] ~] ~]])
::
::  +node-executor: applies a message to a node in a route
::
::    Returns a list of return messages (ignored at the toplevel) and the
::    modified node state. The flow of the node-executor is to dispatch to
::    hierarchical set of nodes. Let's say we have the following node tree:
::
::      /
::      /board
::      /board/123
::      /board/456
::
::    The way to think of a message is as a series of function calls. We call
::    +on-route in /, which generates the parent event for +on-route in /board,
::    which generates the parent event in /board/123. You then call /board/123
::    with the user's request. You then route the return value from /board/123
::    to /board, from /board to /, and then use the assumed [%accept
::    ~]/[%reject ~] return call from the toplevel node.
::
::    TODO: vase to (unit vase)? Right now !>(~) lets me make progress but
::    is wrong in the error handling case
::
::    TODO: Archive events need to go in the log.
::
::
++  node-executor
  |=  $:  parent-event=vase
          route=path
          full-path=path
          message=vase
          state=node-state
      ==
  ^-  [vase _state]
  ::
  ~&  [%full-path full-path]
  ::
  =/  app-vase=vase  (~(got by app-map) app-type.state)
  ::  If we still have remaining path elements, dispatch on them.
  ::
  ?^  route
    ::
    ~&  [%keys (turn ~(tap by children.state) head)]
    ::
    ?~  sub-node=(~(get by children.state) i.route)
      ~&  [%four-oh-four i.route]
      [!>(~) state]
    ::
    =/  on-route=vase  (slap app-vase [%limb %on-route])
    =/  args  :(slop !>(route) parent-event private-state.state)
    =/  raw-result  (slam on-route args)
    ::  raw-result is a (unit *), where we abort processing if we get a sig
    ::  back
    ::
    ?:  =(~ q.raw-result)
      ~&  [%node-canceled-event ~]
      [!>(~) state]
    ::
    =/  child-event=vase  (slot 3 raw-result)
    ::
    =^  return-value  u.sub-node
      (node-executor child-event t.route full-path message u.sub-node)
    ::
    ::  what we want is to mandate a single return value instead of an
    ::  arbitrary list. this really requires that the types above line up
    ::  differently.
    ::
    =/  on-child-return=vase  (slap app-vase [%limb %on-child-return])
    =.  args  :(slop return-value private-state.state)
    =/  raw-result  (slam on-child-return args)
    ::
    =/  return-event=vase  (slot 2 raw-result)
    =.  private-state.state  (slot 3 raw-result)
    ::
    ~&  [%ret return-event]
    [return-event state]
  ::  we've reached the node we're trying to talk to.
  ::
  =/  on-process-event=vase  (slap app-vase [%limb %on-process-event])
  =/  args  :(slop parent-event message private-state.state)
  =/  raw-result  (slam on-process-event args)
  ::
  =/  response=on-process-response  (sump (slot 2 raw-result))
  =.  private-state.state  (slot 3 raw-result)
  ::
  ?-    -.response
      %log
    ::  when we receive a %log event, we commit this to the event log
    ::
    =/  apply-event-to-snapshot=vase
      (slap app-vase [%limb %apply-event-to-snapshot])
    =/  args  :(slop message private-event.response snapshot.state)
    =.  snapshot.state  (slam apply-event-to-snapshot args)
    ::
    ~&  [%log user-event=message private-event=private-event.response]
    =.  event-log.state
      [[next-event-id.state [%log message private-event.response]] event-log.state]
    =.  next-event-id.state  +(next-event-id.state)
    ::
    ~&  [%new-snapshot full-path snapshot.state]
    ::
    [return-event.response state]
  ::
      %create
    ::  w
    ::
    =/  new-item-vase=vase       (~(got by app-map) type.response)
    ::
    =/  snapshot-type=vase       (slap new-item-vase [%limb %snapshot])
    =/  private-state-type=vase  (slap new-item-vase [%limb %private-state])
    ::
    =/  thread=node-state
      :*  type.response
          1
          ~
          (bunt-a-vase snapshot-type)
          (bunt-a-vase private-state-type)
          ~
      ==
    ::
    =^  return  thread
      (node-executor child-event.response / (weld full-path [sub-id.response ~]) message thread)
    ::
    ~&  [%created sub-id=sub-id.response return=return]
    =.  children.state  (~(put by children.state) sub-id.response thread)
    =.  event-log.state
      [[next-event-id.state [%create sub-id.response app-type.state]] event-log.state]
    =.  next-event-id.state  +(next-event-id.state)
    ::
    [return state]
  ::
      %return
    ::  when we receive a %return value, we pass the value up to the callers
    ::
    [return-event.response state]
  ==
--
:-  %say
|=  $:  {now/@da eny/@uvJ bec/beak}
        ~
        ~
    ==
:-  %noun
::
::  from outside, we receive [first-parent /board/123 user-event]

::  (on-route:/ ring-signature)
::  (on-route:/board <result above>)
::  (on-route:/board/123 <result above> user-event)

::
::  the event flow is:
::
::  - parent-event is either received from outside or the direct parent node.
::    - first-parent is sent to (on-route / first-parent)
::    - then (on-route /board <return value above>)
::    - then (on-process-event /board/thread <return value above> user-event)
::
::  This works for the thread (sorta) but where does spawning behaviour come in?
::

=/  board=node-state
  [%board 0 ~ !>(*snapshot:node-type-board) !>(*private-state:node-type-board) ~]
~&  %start---post--a
=^  returns  board  (node-executor !>(0) / / !>([%new-post [0 'subject' 'text']]) board)
~&  %start---post--b
::
=^  ret2  board  (node-executor !>(0) /1 /1 !>([%new-post [0 'reply' 'text reply']]) board)
::
~&  [%board-private-state private-state.board]
0
