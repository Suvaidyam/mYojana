import frappe
# from myojana.utils.filter import Filter
from myojana.utils.cache import Cache

class ReportFilter:
    def set_report_filters(filters=None, date_column='creation', str=False, table_name=None, role_per_filter=True):
        cond_str = Cache.get_user_permission(True,table_name)
        new_filters = {}
        str_list = []
        if table_name:
            date_column = f"{table_name}.{date_column}"
        if filters is None:
            return new_filters
        if filters.from_date and filters.to_date:
            from_date = frappe.db.escape(str(filters.from_date))[1:-1]
            to_date = frappe.db.escape(str(filters.to_date))[1:-1]
            if str:
                str_list.append(
                    f"({date_column} between '{from_date}' AND '{to_date}')")
            else:
                new_filters[date_column] = ["between", [
                    filters.from_date, filters.to_date]]
        elif filters.from_date:
            from_date = frappe.db.escape(str(filters.from_date))[1:-1]
            if str:
                str_list.append(f"({date_column} >= '{from_date}')")
            else:
                new_filters[date_column] = [">=", filters.from_date]
        elif filters.to_date:
            to_date = frappe.db.escape(str(filters.to_date))[1:-1]
            if str:
                str_list.append(f"({date_column} <= '{to_date}')")
            else:
                new_filters[date_column] = ["<=", filters.to_date]

        for filter_key in filters:
            if filter_key not in ['from_date', 'to_date']:
                if str:
                    escaped_val = frappe.db.escape(str(filters[filter_key]))[1:-1]
                    if table_name:
                        str_list.append(f"({table_name}.{filter_key}='{escaped_val}')")
                    else:
                        str_list.append(f"({filter_key}='{escaped_val}')")
                else:
                    new_filters[filter_key] = filters[filter_key]

        if role_per_filter and ("Administrator" not in frappe.get_roles(frappe.session.user)):
            if str and len(cond_str) > 0:
                str_list.append(cond_str)
        if str:
            return ' AND '.join(str_list)
        else:
            return new_filters
