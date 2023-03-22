# Loopback processing 
### Normal Group Policy processing 
Computers located in their organizational unit have the GPOs applied in order during computer startup. 
Users in their organizational unit have GPOs applied in order during logon, regardless of which computer they log on to.

### Loopback Group Policy processing  
 - Merge Mode  

In this mode, when the user logs on, the user's list of GPOs is typically gathered by using the **GetGPOList** function. 
The **GetGPOList** function is then called again by using the computer's location in Active Directory. 

The user settings defined in the computer's GPO is then added to the end of the user settings GPOs normally applied to the user.  
It causes the computer's GPOs to have higher precedence than the user's GPOs.  
If the settings conflict, the user settings in the computer's Group Policy objects take precedence over the user's normal settings.


-   Replace Mode   
In this mode, the user's list of GPOs isn't gathered. Only the list of GPOs based on the computer object is used.
Thus the user settings defined in the computer's Group Policy objects replace the user settings normally applied to the user.


### How to configure loopback processing
In the Group Policy Management Editor,  the loopback setting is located under 
```
Computer Configuration/Administrative Templates/System/Group Policy
```
Use the policy setting ```Configure user Group Policy loopback processing mode``` to configure loopback 


### Breaking it down
 1. It is a computer configuration setting. 
 2. When enabled, user settings from GPOs applied to the computer apply to the logged on user.
 3. Changes the list of applicable GPOs and the order in which they apply to a user.





