# RULES BY ROLES
# 'director', 'encargado', 'staff'

# TEMPLATE
# allow(requester: Requester, "", user: UserResource) if

# USERS

# get_user: allowed for directors, the encargado of the user's daycare, or the user themself
allow(requester: Requester, "get_user", user: UserResource) if
    requester.role = "director"
    or (requester.role = "encargado" and user.daycare_id = requester.daycare_id)
    or requester.id = user.user_id;

# update_user: profile-only fields (name/lastname/email/position/is_active),
# allowed for the encargado of the user's daycare or the user themself.
# role_id and daycare_id are NOT part of this action's payload (see
# UserProfileUpdate) precisely so this rule can stay self-serviceable
# without becoming a privilege-escalation path.
allow(requester: Requester, "update_user", user: UserResource) if
    (requester.role = "encargado" and user.daycare_id = requester.daycare_id)
    or requester.id = user.user_id;

# update_user_role: changing a user's role (or reassigning their daycare) is
# the sensitive operation update_user deliberately excludes. Director-only,
# since this is also how a director turns an existing staff member into a
# new encargado (responsable) of a daycare.
allow(requester: Requester, "update_user_role", _user: UserResource) if
    requester.role = "director";


# DAYCARE

# create_daycare: director-only; creating a daycare is an org-wide action,
# not something scoped to an encargado's own daycare.
allow(requester: Requester, "create_daycare", _resource: Requester) if
    requester.role = "director";

# get_daycare: allowed for members of the same daycare
allow(requester: Requester, "get_daycare", daycare: DaycareResource) if
    requester.daycare_id = daycare.daycare_id;

# get_daycare_information: allowed for directors or the encargado of the same daycare
allow(requester: Requester, "get_daycare_information", daycare: DaycareResource) if
    (requester.role = "encargado" and requester.daycare_id = daycare.daycare_id)
    or requester.role = "director";

# update_daycare: allowed only for the encargado of the same daycare
allow(requester: Requester, "update_daycare", daycare: DaycareResource) if
    requester.role = "encargado" and requester.daycare_id = daycare.daycare_id;


# AREAS

# get_area: allowed for directors or members of the same daycare
allow(requester: Requester, "get_area", area: AreaResource) if
    requester.role = "director"
    or requester.daycare_id = area.daycare_id;

# alter_areas: allowed only for the encargado of the same daycare
allow(requester: Requester, "alter_areas", area: AreaResource) if
    requester.role = "encargado" and requester.daycare_id = area.daycare_id;

# get_area_information: allowed for directors or the encargado of the same daycare
allow(requester: Requester, "get_area_information", area: AreaResource) if
    requester.role = "director"
    or (requester.role = "encargado" and requester.daycare_id = area.daycare_id);


# INVITATION CODE

# create_invitation: an encargado may only invite new staff into their own
# daycare (never another encargado or director); a director may only invite
# new encargados (responsables) -- this is how the business rule "director
# creates new responsables of each daycare" is implemented.
allow(requester: Requester, "create_invitation", invitation: InvitationCodeResource) if
    requester.role = "encargado" and requester.daycare_id = invitation.daycare_id and invitation.role = "staff";

allow(requester: Requester, "create_invitation", invitation: InvitationCodeResource) if
    requester.role = "director" and invitation.role = "encargado";


# REQUEST

# get_request: allowed for directors, the encargado of the same daycare, or the user who made it
allow(requester: Requester, "get_request", request: RequestResource) if
    requester.role = "director"
    or (requester.role = "encargado" and requester.daycare_id = request.daycare_id)
    or requester.id = request.user_id;

# create_request: allowed only for staff, on their own behalf
allow(requester: Requester, "create_request", request: RequestResource) if
    requester.role = "staff" and requester.id = request.user_id;

# resolve_request: approve/reject an existing request. Only someone with
# authority over the requester's daycare may do this -- never the staff
# member who filed it
allow(requester: Requester, "resolve_request", request: RequestResource) if
    requester.role = "director"
    or (requester.role = "encargado" and requester.daycare_id = request.daycare_id);


# SHIFT

# get_shift: allowed for directors, the encargado of the same daycare, or the assigned employee
allow(requester: Requester, "get_shift", shift: ShiftResource) if
    requester.role = "director"
    or (requester.role = "encargado" and requester.daycare_id = shift.daycare_id)
    or requester.id = shift.user_id;

# alter_shifts: allowed only for the encargado of the same daycare
allow(requester: Requester, "alter_shifts", shift: ShiftResource) if
    requester.role = "encargado" and requester.daycare_id = shift.daycare_id;


# ATTENDANCE

# create_attendance: allowed for the encargado of the same daycare or the employee concerned
allow(requester: Requester, "create_attendance", attendance: AttendanceResource) if
    (requester.role = "encargado" and requester.daycare_id = attendance.daycare_id)
    or requester.id = attendance.user_id;

# update_attendance: allowed only for the encargado of the same daycare
allow(requester: Requester, "update_attendance", attendance: AttendanceResource) if
    requester.role = "encargado" and requester.daycare_id = attendance.daycare_id;


# PERSONNEL HISTORY

# create_history: allowed only for the encargado of the same daycare. The
# subject of the record is deliberately excluded here -- personnel history
# is an HR record, not self-reported data; letting a user write their own
# history entries would let them fabricate it.
allow(requester: Requester, "create_history", history: HistoryResource) if
    requester.role = "encargado" and requester.daycare_id = history.daycare_id;

# get_history: allowed for directors, the encargado of the same daycare, or the user concerned
allow(requester: Requester, "get_history", history: HistoryResource) if
    requester.role = "director"
    or (requester.role = "encargado" and requester.daycare_id = history.daycare_id)
    or requester.id = history.user_id;

# update_history: allowed only for the encargado of the same daycare
allow(requester: Requester, "update_history", history: HistoryResource) if
    requester.role = "encargado" and requester.daycare_id = history.daycare_id;
