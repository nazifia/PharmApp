lib/
├── core/
│   ├── database/
│   │   ├── database_provider.dart
│   │   ├── schemas/
│   │   │   ├── user_schema.dart
│   │   │   ├── item_schema.dart
│   │   │   ├── cart_schema.dart
│   │   │   ├── customer_schema.dart
│   │   │   ├── sale_schema.dart
│   │   │   └── supplier_schema.dart
│   │   ├── repositories/
│   │   │   ├── user_repository.dart
│   │   │   ├── item_repository.dart
│   │   │   ├── cart_repository.dart
│   │   │   ├── customer_repository.dart
│   │   │   ├── sale_repository.dart
│   │   │   └── supplier_repository.dart
│   │   └── migrations/
│   │       ├── version_1_0.dart
│   │       └── version_2_0.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── cart_provider.dart
│   │   ├── inventory_provider.dart
│   │   ├── customer_provider.dart
│   │   ├── sale_provider.dart
│   │   ├── sync_provider.dart
│   │   └── theme_provider.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── sync_service.dart
│   │   ├── payment_service.dart
│   │   ├── barcode_service.dart
│   │   ├── notification_service.dart
│   │   └── analytics_service.dart
│   ├── router/
│   │   ├── app_router.dart
│   │   ├── guards/
│   │   │   ├── auth_guard.dart
│   │   │   ├── role_guard.dart
│   │   │   └── permission_guard.dart
│   │   └── routes/
│   │       ├── auth_routes.dart
│   │       ├── dashboard_routes.dart
│   │       ├── inventory_routes.dart
│   │       ├── pos_routes.dart
│   │       └── customer_routes.dart
│   └── theme/
│       ├── app_theme.dart
│       ├── theme_provider.dart
│       ├── dark_theme.dart
│       └── adaptive_theme.dart
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── phone_auth_screen.dart
│   │   │   ├── role_selection_screen.dart
│   │   │   └── setup_screen.dart
│   │   ├── widgets/
│   │   │   ├── auth_form.dart
│   │   │   ├── phone_input.dart
│   │   │   └── role_card.dart
│   │   └── providers/
│   │       ├── auth_provider.dart
│   │       └── phone_auth_provider.dart
│   ├── dashboard/
│   │   ├── screens/
│   │   │   ├── main_dashboard.dart
│   │   │   ├── retail_dashboard.dart
│   │   │   ├── wholesale_dashboard.dart
│   │   │   ├── analytics_dashboard.dart
│   │   │   └── notifications_screen.dart
│   │   ├── widgets/
│   │   │   ├── dashboard_card.dart
│   │   │   ├── quick_actions.dart
│   │   │   ├── stats_widget.dart
│   │   │   └── navigation_drawer.dart
│   │   └── providers/
│   │       ├── dashboard_provider.dart
│   │       └── analytics_provider.dart
│   ├── inventory/
│   │   ├── screens/
│   │   │   ├── inventory_list_screen.dart
│   │   │   ├── low_stock_screen.dart
│   │   │   ├── item_detail_screen.dart
│   │   │   └── batch_management_screen.dart
│   │   ├── widgets/
│   │   │   ├── item_card.dart
│   │   │   ├── search_bar.dart
│   │   │   ├── filter_panel.dart
│   │   │   └── stock_alert.dart
│   │   └── providers/
│   │       ├── inventory_provider.dart
│   │       └── search_provider.dart
│   ├── pos/
│   │   ├── screens/
│   │   │   ├── retail_pos_screen.dart
│   │   │   ├── wholesale_pos_screen.dart
│   │   │   ├── cashier_screen.dart
│   │   │   └── payment_screen.dart
│   │   ├── widgets/
│   │   │   ├── cart_item_widget.dart
│   │   │   ├── payment_method_card.dart
│   │   │   ├── split_payment_dialog.dart
│   │   │   ├── barcode_scanner.dart
│   │   │   └── receipt_printer.dart
│   │   └── providers/
│   │       ├── cart_provider.dart
│   │       ├── pos_provider.dart
│   │       └── payment_provider.dart
│   ├── customers/
│   │   ├── screens/
│   │   │   ├── customer_list_screen.dart
│   │   │   ├── customer_detail_screen.dart
│   │   │   ├── wallet_screen.dart
│   │   │   └── transaction_history_screen.dart
│   │   ├── widgets/
│   │   │   ├── customer_card.dart
│   │   │   ├── wallet_balance.dart
│   │   │   └── transaction_item.dart
│   │   └── providers/
│   │       ├── customer_provider.dart
│   │       └── wallet_provider.dart
│   ├── wholesale/
│   │   ├── screens/
│   │   │   ├── wholesale_orders_screen.dart
│   │   │   ├── supplier_management_screen.dart
│   │   │   ├── bulk_order_screen.dart
│   │   │   └── delivery_management_screen.dart
│   │   ├── widgets/
│   │   │   ├── order_card.dart
│   │   │   ├── supplier_card.dart
│   │   │   └── delivery_status.dart
│   │   └── providers/
│   │       ├── wholesale_provider.dart
│   │       └── supplier_provider.dart
│   ├── reports/
│   │   ├── screens/
│   │   │   ├── sales_report_screen.dart
│   │   │   ├── inventory_report_screen.dart
│   │   │   ├── customer_report_screen.dart
│   │   │   └── profit_report_screen.dart
│   │   ├── widgets/
│   │   │   ├── chart_widget.dart
│   │   │   ├── filter_date_range.dart
│   │   │   └── export_button.dart
│   │   └── providers/
│   │       ├── report_provider.dart
│   │       └── analytics_provider.dart
│   └── settings/
│       ├── screens/
│       │   ├── app_settings_screen.dart
│       │   ├── user_profile_screen.dart
│       │   ├── backup_restore_screen.dart
│       │   └── sync_settings_screen.dart
│       ├── widgets/
│       │   ├── setting_item.dart
│       │   ├── toggle_switch.dart
│       │   └── version_info.dart
│       └── providers/
│           ├── settings_provider.dart
│           └── sync_provider.dart
├── shared/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── item_model.dart
│   │   ├── cart_model.dart
│   │   ├── customer_model.dart
│   │   ├── sale_model.dart
│   │   ├── supplier_model.dart
│   │   ├── payment_model.dart
│   │   └── batch_model.dart
│   ├── widgets/
│   │   ├── custom_button.dart
│   │   ├── custom_textfield.dart
│   │   ├── loading_spinner.dart
│   │   ├── error_widget.dart
│   │   └── empty_state.dart
│   └── utils/
│       ├── constants.dart
│       ├── validators.dart
│       ├── formatters.dart
│       └── helpers.dart
└── main.dart