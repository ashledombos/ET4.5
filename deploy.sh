######## Script Quartz
##### RECUPERATION DE L'ADRESSE IP EN FONCTION DU NOM
get_ip_from_name()
{
         local NOM=$1
         grep $NOM /var/run/edu_computers  | awk -F: '{print $1}'
}
get_building_from_shortname()
{
        local STRUC=$1
        grep $STRUC /root/action/STRUCTURES | awk -F: '{print $1}'
}

##### CHOIX DU GROUPE A INSTALLER
echo "Choisissez le groupe à installer"
cat /root/action/STRUCTURES
read -p "Votre choix :" GROUPE
BAT=$(get_building_from_shortname $GROUPE)
echo $GROUPE
echo "Vous avez choisi ${BAT}"
echo "Appuyez sur une touche pour procéder"
read -n1
echo "`date`" > c
echo "`date`" > nc

##### BOUCLE QUI VA AGIR SUR TOUS LES ORDINATEURS DU GROUPE
old_IFS=$IFS     # sauvegarde du séparateur de champ  
IFS=$'\n'
for MACHINE in $(cat /root/action/${GROUPE})
do
        echo "Machine en cours"
        echo -e "NOM : $MACHINE"
        cat ${GROUPE}_imp
        ADDRIP=$(get_ip_from_name $MACHINE)
        export ADDRIP
        echo -e "IP : $ADDRIP"
        ##### TEST D'ACTIVITE DE LA MACHINE
        echo "Test si machine allumée"
        netcat -z $ADDRIP 22
        if [ $? = 0 ]
        then
                echo ""
                echo "OK : $MACHINE JOIGNABLE"
                echo ""
                echo "Vérification si les logiciels suivants sont installés"

                ##### INSTALLATION DES LOGICIELS
                for SOFT in $(cat /root/action/LOGICIELS)
                do
                        echo $SOFT
                        /usr/sbin/urpmi --no-verify-rpm --auto --parallel $MACHINE $SOFT
               done
                echo "Installation des logiciels : OK"
                echo ""

                ##### CONFIGURATION DE CUPS et XSANE
                echo "Configuration de Cups et Xsane"
                ssh $ADDRIP 'bash -c "hostname && rm /etc/cups/client.conf;echo "" > /etc/cups/printers.conf;echo 10.42.42.1 > /etc/sane.d/net.conf;service cups restart"'
                echo "Cups et Xsane : OK"
                echo ""
                ##### FUSION INVENTORY
                echo "Fusion Inventory"
                scp -pr fi/fusioninventory $ADDRIP:/etc/
                scp -pr fi/fusioninventory-agent $ADDRIP:/etc/cron.d/
                # ssh $ADDRIP 'bash -c "urpme fusioninventory-agent --auto --force"'
                # ssh $ADDRIP 'bash -c "urpmi fusioninventory-agent --allow-force"'
                # ssh $ADDRIP 'bash -c "fusioninventory-agent --lazy > /dev/null 2>&1"'
                ssh $ADDRIP 'bash -c "fusioninventory-agent > /dev/null 2>&1"'
                ##### CONFIGURATION DES IMPRIMANTES BOUCLE SUR FICHIER LISTE DES IMPRIMANTES
                echo "Configuration des imprimantes"
                for IMP in $(cat /root/action/${GROUPE}_imp)
                do
                        SSH_CMD="bash -c \"echo $IMP && lpadmin -p $IMP -E -v ipp://10.42.42.1/printers/$IMP\""
                        ssh $ADDRIP $SSH_CMD
                        echo "OK"
                done
                echo "Configuration des imprimantes : OK"
                scp nettoie-fichiers.desktop $ADDRIP:/usr/share/autostart
                scp nettoiefichiers.sh $ADDRIP:/usr/local/bin
                scp autostart.desktop $ADDRIP:/usr/share/autostart
                scp autostart.sh $ADDRIP:/usr/local/bin
                rsync -az /usr/share/fonts/ttf/msttcorefonts $ADDRIP:/usr/share/fonts/ttf
                ##### SCRIPTS TEMPORAIRES
                #ssh $ADDRIP 'bash -c "urpme kernel-desktop-3.1.6-69mib --auto --force"'
                #ssh $ADDRIP 'bash -c "chown -R sbegin /home/sbegin"'
                #ssh $ADDRIP 'bash -c "chown -R sbegin1 /home/sbegin1"'
                ##### FIN
                #echo "`date`" > c
                echo "Machine $MACHINE ok" >> c
                echo "$MACHINE OK"
                echo ""
        else
                echo ""
                echo "/!\ $MACHINE INJOIGNABLE /!\\"
                echo ""

                #echo "`date`" > nc
                echo "Machine $MACHINE injoignable" >> nc
        fi
done
IFS=$old_IFS #Récupération de l'ancien séparateur de champs
echo "Les machines suivantes n'ont pas pu être jointes :"
cat nc
