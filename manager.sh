#!/bin/bash

while true
do
echo ""
echo "--- Meniu ---"
echo "1) Inregistrare"
echo "2) Autentificare"
echo "3) Generare raport pe utilizator"
echo "4) Schimbare parola"
echo "5) Iesire"
echo ""
echo -n "Alege optiunea: "
read optiune
echo ""

case $optiune in
1)
if [ ! -f users.csv ]; then
echo "ID,Username,Email,Salt,Hash,HomeDirectory,LastLogin" > users.csv
echo "===================================================" >> users.csv
echo "Fisierul 'users.csv' a fost creat automat"
echo ""
fi

echo -n "Username: "
read username
if grep -q ",$username," users.csv; then
echo "Utilizatorul '$username' deja exista"
echo "Alege alt username"
continue
fi

echo -n "Email: "
read email
if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
echo "Adresa de email este invalida"
continue
elif grep -q ",$email," users.csv; then
echo "Emailul '$email' este deja utilizat"
continue
fi

echo -n "Parola: "
read -s parola
echo ""
echo -n "Confirmare parola: "
read -s parola_confirmata
echo ""
echo ""
if [ "$parola" != "$parola_confirmata" ]; then
echo "Parola incorecta"
continue
fi

salt=$(date +%s%N)$RANDOM$$
salt=$(echo "$salt" | sed 's/[^a-zA-Z0-9]//g')
salt=${salt:0:16}
parola_hash=$(echo -n "$salt$parola" | sha256sum | sed 's/ .*//')

last_line=$(tail -n 1 users.csv)
if [[ ! "$last_line" =~ ^[0-9] ]]; then
id=1
else
max_id="${last_line%%,*}"
id=$((max_id + 1))
fi

main_home="./Home"
if [ ! -d "$main_home" ]; then
mkdir -p "$main_home"
echo "Utilizatori logati" > "$main_home/logged_in_users.txt"
echo "==================" >> "$main_home/logged_in_users.txt"
fi
home_dir="$main_home/$username"
mkdir -p "$home_dir"

if [ ! -f "$home_dir/.logout.sh" ]; then
echo "#!/bin/bash" > "$home_dir/.logout.sh"
echo 'username=$(basename "$PWD")' >> "$home_dir/.logout.sh"
echo 'logged_in_file="../logged_in_users.txt"' >> "$home_dir/.logout.sh"
echo 'if grep -q "^$username\$" "$logged_in_file"; then' >> "$home_dir/.logout.sh"
echo 'sed -i "/^$username\$/d" "$logged_in_file"' >> "$home_dir/.logout.sh"
echo 'echo ""' >> "$home_dir/.logout.sh"
echo 'echo "Te-ai delogat cu succes, $username!"' >> "$home_dir/.logout.sh"
echo 'echo ""' >> "$home_dir/.logout.sh"
echo "cd ../.." >> "$home_dir/.logout.sh"
echo "else" >> "$home_dir/.logout.sh"
echo 'echo ""' >> "$home_dir/.logout.sh"
echo "echo \"Utilizatorul '\$username' nu este autentificat\"" >> "$home_dir/.logout.sh"
echo 'echo ""' >> "$home_dir/.logout.sh"
echo "fi" >> "$home_dir/.logout.sh"
chmod +x "$home_dir/.logout.sh"
fi


echo "$id,$username,$email,$salt,$parola_hash,$home_dir" >> users.csv
echo "Utilizatorul '$username' a fost inregistrat"

(
echo "From: \"Echipa_4SO\" <echipa4so@gmail.com>"
echo "To: $email"
echo "Subject: Cont creat cu succes"
echo ""
echo "Salut, $username!"
echo ""
echo "Contul tau a fost creat cu succes in sistemul de gestionare utilizatori."
echo "ID-ul tau este: $id"
echo "Parola ta este: $parola"
echo "Directorul tau home este: $home_dir"
echo ""
echo "Multumim,"
echo "Echipa de administrare"
) | sendmail -t
echo "Email de confirmare trimis la $email"
;;

2)
echo -n "Username: "
read login_username

login_line=$(grep -a ",$login_username," users.csv)
if [ -z "$login_line" ]; then
echo "Utilizatorul '$login_username' nu a fost gasit"
continue
fi

echo -n "Parola: "
read -s login_parola
echo ""
echo ""

salt_fisier=${login_line#*,*,*,}
salt_fisier=${salt_fisier%%,*}
hash_fisier=${login_line#*,*,*,*,}
hash_fisier=${hash_fisier%%,*}

login_hash=$(echo -n "$salt_fisier$login_parola" | sha256sum | sed 's/ .*//')
if [ "$login_hash" != "$hash_fisier" ]; then
echo "Parola gresita"
continue
else
echo "Bine ai venit, $login_username!"
fi

data_curenta=$(date "+%Y-%m-%d %H:%M:%S")
nr_virgule=$(echo "$login_line" | sed 's/[^,]//g')

if [ "${#nr_virgule}" -eq 6 ]; then
login_line_modif=${login_line%,*}
new_login_line="$login_line_modif,$data_curenta"
sed -i "s|^$login_line\$|$new_login_line|" users.csv
else
new_login_line="$login_line,$data_curenta"
sed -i "s|^$login_line\$|$new_login_line|" users.csv
fi

main_home="./Home"
logged_in_file="$main_home/logged_in_users.txt"

if ! grep -q "^$login_username\$" "$logged_in_file"; then
echo "$login_username" >> "$logged_in_file"
fi

export login_dir="$main_home/$login_username"
break
;;

3)
echo -n "Username: "
read raport_username

raport_line=$(grep ",$raport_username," users.csv)
if [ -z "$raport_line" ]; then
echo "Utilizatorul '$raport_username' nu exista"
else

home_dir_raport=${raport_line#*,*,*,*,*,}
home_dir_raport=${home_dir_raport%%,*}

if [ ! -d "$home_dir_raport" ]; then
echo "Directorul personal al utilizatorului '$raport_username' nu exista"
else

fisier_raport="$home_dir_raport/.raport.txt"
echo "Se genereaza raportul..."
sleep 5

set +m
{
echo "Raport pentru utilizatorul $raport_username"
echo "==========================================="
data_generare=$(date "+%Y-%m-%d %H:%M")
echo "Data generarii: $data_generare"
echo ""

nr_fisiere=$(find "$home_dir_raport" -type f ! -name ".raport.txt" ! -name ".logout.sh" | wc -l)
nr_directoare=$(find "$home_dir_raport" -type d | wc -l)
echo "Numar de fisiere: $nr_fisiere"
echo "Numar de directoare: $nr_directoare"
echo ""

if [ "$nr_fisiere" -ne 0 ]; then
echo "Lista fisierelor si dimensiunile lor:"
find "$home_dir_raport" -type f ! -name ".raport.txt" ! -name ".logout.sh" | while read -r fisier; do
dimensiune=$(stat -c%s "$fisier")
echo "$fisier - $dimensiune bytes"
done
fi
} > "$fisier_raport" &

echo "Raportul pentru utilizatorul '$raport_username' a fost salvat in directorul sau personal"
echo "Pentru a il vizualiza, autentificati-va sub username-ul '$raport_username', tastati 'raport' si apasati tasta 'Enter'"
fi

fi
;;

4)
echo -n "Username: "
read newpsswd_username

newpsswd_line=$(grep -a ",$newpsswd_username," users.csv)

if [ -z "$newpsswd_line" ]; then
echo "Utilizatorul '$newpsswd_username' nu a fost gasit"
continue
fi

newpsswd_nr_virgule=$(echo "$newpsswd_line" | sed 's/[^,]//g')
if [ "${#newpsswd_nr_virgule}" -ne 6 ]; then
echo "Ca sa va puteti schimba parola trebuie sa va autentificati mai intai"
continue
fi

echo -n "Parola: "
read -s newpsswd_parola
echo ""
echo ""

salt_fisier=${newpsswd_line#*,*,*,}
salt_fisier=${salt_fisier%%,*}
hash_fisier=${newpsswd_line#*,*,*,*,}
hash_fisier=${hash_fisier%%,*}

newpsswd_hash=$(echo -n "$salt_fisier$newpsswd_parola" | sha256sum | sed 's/ .*//')
if [ "$newpsswd_hash" != "$hash_fisier" ]; then
echo "Parola gresita"
continue
fi

echo -n "Parola noua: "
read -s parola_noua
echo ""
echo -n "Confirmare parola noua: "
read -s parola_noua_confirmata
echo ""
echo ""

if [ "$parola_noua" != "$parola_noua_confirmata" ]; then
echo "Parola noua incorecta"
continue
fi

salt_nou=$(date +%s%N)$RANDOM$$
salt_nou=$(echo "$salt_nou" | sed 's/[^a-zA-Z0-9]//g')
salt_nou=${salt_nou:0:16}
parola_hash_noua=$(echo -n "$salt_nou$parola_noua" | sha256sum | sed 's/ .*//')

home_dir_newpsswd=${newpsswd_line#*,*,*,*,*,}
home_dir_newpsswd=${home_dir_newpsswd%%,*}
last_login_newpsswd=${newpsswd_line##*,}
newpsswd_line_modif=${newpsswd_line%,*,*,*,*}

newpsswd_new_line="$newpsswd_line_modif,$salt_nou,$parola_hash_noua,$home_dir_newpsswd,$last_login_newpsswd"
sed -i "s|^$newpsswd_line\$|$newpsswd_new_line|" users.csv

echo "Parola utilizatorului '$newpsswd_username' a fost schimbata"

newpsswd_email=${newpsswd_line_modif##*,}

(
echo "From: \"Echipa_4SO\" <echipa4so@gmail.com>"
echo "To: $newpsswd_email"
echo "Subject: Parola schimbata"
echo ""
echo "Salut, $newpsswd_username!"
echo ""
echo "Parola contului tau a fost modificata cu succes."
echo "Noua ta parola este: $parola_noua"
echo ""
echo "Multumim,"
echo "Echipa de administrare"
) | sendmail -t
echo "Email de confirmare trimis la $newpsswd_email"
;;

5)
echo "La revedere!"
break
;;

*)
echo "Optiune invalida"
;;
esac

done

if [ -n "$login_dir" ]; then
cd "$login_dir"
echo "Te afli in directorul tau personal"
echo "Tasteaza 'logout' si apasa tasta 'Enter' pentru a te deloga"
echo ""
unset login_dir
fi


