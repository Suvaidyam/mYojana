import frappe
def list_query(user):
    if not user:
        user = frappe.session.user
    if "Administrator" not in frappe.get_roles(user) and "Admin" not in frappe.get_roles(user):
        profile_condition = frappe.db.escape(user)
        return f"(`tabUser`.name = {profile_condition})"

