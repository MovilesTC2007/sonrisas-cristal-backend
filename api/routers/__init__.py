from routers import (
    areas,
    attendance,
    auth,
    catalog,
    daycares,
    health,
    history,
    requests,
    shifts,
    users,
)

ALL_ROUTERS = [
    health.router,
    auth.router,
    auth.invitations_router,
    catalog.router,
    daycares.router,
    areas.router,
    users.router,
    requests.router,
    shifts.router,
    attendance.router,
    history.router,
]
