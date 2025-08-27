from django import forms
from .models import *
from customer.models import Customer
from supplier.models import *
from django.contrib.auth.forms import UserChangeForm
from django.forms import modelformset_factory


UNIT = [
    ('Amp', 'Amp'),
    ('Bottle', 'Bottle'),
    ('Drops', 'Drops'),
    ('Tab', 'Tab'),
    ('Tin', 'Tin'),
    ('Can', 'Can'),
    ('Caps', 'Caps'),
    ('Card', 'Card'),
    ('Carton', 'Carton'),
    ('Pack', 'Pack'),
    ('Sachets', 'Sachets'),
    ('Pcs', 'Pcs'),
    ('Roll', 'Roll'),
    ('Vail', 'Vail'),
    ('1L', '1L'),
    ('2L', '2L'),
    ('4L', '4L'),
]



MARKUP_CHOICES = [
        (0, 'No markup'),
        (2.5, '2.5% markup'),
        (5, '5% markup'),
        (7.5, '7.5% markup'),
        (10, '10% markup'),
        (12.5, '12.5% markup'),
        (15, '15% markup'),
        (17.5, '17.5% markup'),
        (20, '20% markup'),
        (22.5, '22.5% markup'),
        (25, '25% markup'),
        (27.5, '27.5% markup'),
        (30, '30% markup'),
        (32.5, '32.5% markup'),
        (35, '35% markup'),
        (37.5, '37.5% markup'),
        (40, '40% markup'),
        (42.5, '42.5% markup'),
        (45, '45% markup'),
        (47.5, '47.5% markup'),
        (50, '50% markup'),
        (57.5, '57.5% markup'),
        (60, '60% markup'),
        (62.5, '62.5% markup'),
        (65, '65% markup'),
        (67.5, '67.5% markup'),
        (70, '70% markup'),
        (72., '72.% markup'),
        (75, '75% markup'),
        (77.5, '77.5% markup'),
        (80, '80% markup'),
        (82.5, '82.% markup'),
        (85, '85% markup'),
        (87.5, '87.5% markup'),
        (90, '90% markup'),
        (92., '92.% markup'),
        (95, '95% markup'),
        (97.5, '97.5% markup'),
        (100, '100% markup'),
    ]



class EditUserProfileForm(UserChangeForm):

    class Meta:
        model = User
        fields = ['username', 'password', 'first_name', 'last_name']


class addItemForm(forms.ModelForm):
    name = forms.CharField(max_length=200)
    dosage_form = forms.CharField(max_length=200)  # Changed to CharField to allow any value
    brand = forms.CharField(max_length=200)
    unit = forms.CharField(max_length=200)  # Already a CharField
    cost = forms.DecimalField(max_digits=12, decimal_places=2)
    markup = forms.DecimalField(max_digits=6, decimal_places=2)
    price = forms.DecimalField(max_digits=12, decimal_places=2, required=False)
    stock = forms.IntegerField()
    exp_date = forms.DateField()

    class Meta:
        model = Item
        fields = ('name', 'dosage_form', 'brand', 'unit', 'cost', 'markup', 'price', 'stock', 'exp_date')



class dispenseForm(forms.Form):
    q = forms.CharField(min_length=2, label='', widget=forms.TextInput(attrs={'class': 'form-control search-input', 'placeholder':'Search by item name or brand...'}))


class CustomerForm(forms.ModelForm):
    class Meta:
        model = Customer
        exclude = ['user']


class AddFundsForm(forms.Form):
    amount = forms.DecimalField(max_digits=10, decimal_places=2)


class DispensingLogSearchForm(forms.Form):
    item_name = forms.CharField(
        max_length=100,
        required=False,
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': 'Search by item name...',
            'autocomplete': 'off'
        }),
        label='Item Name'
    )
    date_from = forms.DateField(
        required=False,
        widget=forms.DateInput(attrs={
            'class': 'form-control',
            'type': 'date',
            'style': 'background-color: rgb(196, 253, 253);'
        }),
        label='From Date'
    )
    date_to = forms.DateField(
        required=False,
        widget=forms.DateInput(attrs={
            'class': 'form-control',
            'type': 'date',
            'style': 'background-color: rgb(196, 253, 253);'
        }),
        label='To Date'
    )
    status = forms.ChoiceField(
        choices=[('', 'All Status')] + STATUS_CHOICES,
        required=False,
        widget=forms.Select(attrs={
            'class': 'form-control'
        }),
        label='Status'
    )
    user = forms.ModelChoiceField(
        queryset=None,  # Will be set dynamically in the view
        required=False,
        empty_label='All Users',
        widget=forms.Select(attrs={
            'class': 'form-control'
        }),
        label='User'
    )

    def __init__(self, *args, **kwargs):
        user_queryset = kwargs.pop('user_queryset', None)
        super().__init__(*args, **kwargs)
        if user_queryset is not None:
            self.fields['user'].queryset = user_queryset



class ReturnItemForm(forms.Form):
    return_item_quantity = forms.IntegerField(
        min_value=1,
        label="Return Quantity",
        widget=forms.NumberInput(attrs={'class': 'form-control mb-3'})
    )
    return_reason = forms.CharField(
        widget=forms.Textarea(attrs={'class': 'form-control mb-3', 'rows': 3}),
        required=True,
        label="Reason for Return"
    )

    def clean_return_item_quantity(self):
        quantity = self.cleaned_data.get('return_item_quantity')
        if quantity <= 0:
            raise forms.ValidationError("Return quantity must be greater than zero.")
        return quantity




class SupplierRegistrationForm(forms.ModelForm):
    class Meta:
        model = Supplier
        fields = ['name', 'phone', 'contact_info']
        widgets = {
            'name': forms.TextInput(attrs={'class': 'form-control'}),
            'phone': forms.TextInput(attrs={'class': 'form-control'}),
            'contact_info': forms.TextInput(attrs={'class': 'form-control'}),
        }






class ProcurementForm(forms.ModelForm):
    class Meta:
        model = Procurement
        fields = ['supplier', 'date']
        widgets = {
            'supplier': forms.Select(attrs={'placeholder': 'Select supplier'}),
            'date': forms.DateInput(attrs={'placeholder': 'Select date', 'type': 'date'}),
        }
        labels = {
            'supplier': 'Supplier',
            'date': 'Date',
        }


class ProcurementItemForm(forms.ModelForm):
    # Add a hidden field for markup with a default value
    markup = forms.FloatField(initial=0, required=False, widget=forms.HiddenInput())

    class Meta:
        model = ProcurementItem
        # Added 'expiry_date' so that it can be input via the form
        fields = ['item_name', 'dosage_form', 'brand', 'unit', 'quantity', 'cost_price', 'markup', 'expiry_date']
        exclude = ['id', 'procurement', 'subtotal']
        widgets = {
            'item_name': forms.TextInput(attrs={'placeholder': 'Enter item name'}),
            'dosage_form': forms.Select(attrs={'placeholder': 'Dosage form'}),
            'brand': forms.TextInput(attrs={'placeholder': 'Enter brand name'}),
            'unit': forms.Select(attrs={'placeholder': 'Select unit'}),
            'quantity': forms.NumberInput(attrs={'placeholder': 'Enter quantity'}),
            'cost_price': forms.NumberInput(attrs={'placeholder': 'Enter cost price'}),
            # Using a date input widget for the expiry_date field
            'expiry_date': forms.DateInput(attrs={'placeholder': 'Select expiry date', 'type': 'date', 'required': False}),
            # Override the markup field to use a hidden input with a default value
            'markup': forms.HiddenInput(),
        }
        labels = {
            'item_name': 'Item Name',
            'dosage_form': 'D/form',
            'brand': 'Brand',
            'unit': 'Unit',
            'quantity': 'Quantity',
            'cost_price': 'Cost Price',
            'expiry_date': 'Expiry Date',
        }

    def clean(self):
        cleaned_data = super().clean()
        # If the form is empty (no item_name), don't validate other fields
        if not cleaned_data.get('item_name'):
            return cleaned_data

        # Validate required fields only if item_name is provided
        required_fields = ['dosage_form', 'unit', 'quantity', 'cost_price']
        for field in required_fields:
            if not cleaned_data.get(field):
                self.add_error(field, f'{field} is required when adding an item')

        # Validate quantity and cost_price are positive
        quantity = cleaned_data.get('quantity')
        if quantity is not None and quantity <= 0:
            self.add_error('quantity', 'Quantity must be greater than zero')

        cost_price = cleaned_data.get('cost_price')
        if cost_price is not None and cost_price <= 0:
            self.add_error('cost_price', 'Cost price must be greater than zero')

        # Set default value for markup if not provided
        if 'markup' not in cleaned_data or cleaned_data.get('markup') is None:
            cleaned_data['markup'] = 0

        return cleaned_data

    def save(self, commit=True):
        instance = super().save(commit=False)
        # Ensure markup has a default value
        if not hasattr(instance, 'markup') or instance.markup is None:
            instance.markup = 0
        if commit:
            instance.save()
        return instance


# Create a custom formset that validates only non-empty forms
class BaseProcurementItemFormSet(forms.BaseModelFormSet):
    def clean(self):
        super().clean()
        # Check that at least one form is filled
        if not any(form.cleaned_data.get('item_name') for form in self.forms if hasattr(form, 'cleaned_data')):
            raise forms.ValidationError('At least one item must be added to the procurement.')

    def _should_delete_form(self, form):
        # Override to consider empty forms as to be deleted
        if not form.has_changed() and not form.cleaned_data.get('item_name'):
            return True
        return super()._should_delete_form(form)

# Ensure that the formset provides an extra form if needed and supports deletion.
ProcurementItemFormSet = modelformset_factory(
    ProcurementItem,
    form=ProcurementItemForm,
    formset=BaseProcurementItemFormSet,
    extra=1,         # Allows one blank form for new entries
    can_delete=True,  # Allows deletion of items dynamically
    fields=['item_name', 'dosage_form', 'brand', 'unit', 'quantity', 'cost_price', 'markup', 'expiry_date'],
    exclude=['id', 'procurement', 'subtotal'],  # Explicitly exclude these fields
    validate_min=False  # Don't validate minimum number of forms
)


class ExpenseCategoryForm(forms.ModelForm):
    class Meta:
        model = ExpenseCategory
        fields = ['name']
        widgets = {
            'name': forms.TextInput(attrs={'class': 'form-control'}),
        }



class ExpenseForm(forms.ModelForm):
    class Meta:
        model = Expense
        fields = ['category', 'amount', 'date', 'description']
        widgets = {
            'category': forms.Select(attrs={'class': 'form-control'}),
            'amount': forms.NumberInput(attrs={'class': 'form-control', 'step': '0.01'}),
            'date': forms.DateInput(attrs={'class': 'form-control', 'type': 'date'}),
            'description': forms.Textarea(attrs={'class': 'form-control', 'rows': 3, 'style': 'resize: vertical;'}),
        }


class StoreSettingsForm(forms.ModelForm):
    class Meta:
        model = StoreSettings
        fields = ['low_stock_threshold']
        widgets = {
            'low_stock_threshold': forms.NumberInput(attrs={'class': 'form-control'})
        }
